# the lobby serv manages the state related to a `lobbies` record
# a game exists in one of several modes:
# 
# - pick_czar    :: the game selects a czar and prompt
# - wait_players :: the game collects player responses
# - wait_czar    :: the game waits for the czar to select a winner
# - announce_winner :: shows a summary message to close out the round
# - idle         :: the lobby waits to be garbage collected
#
# any of these modes may have an optional timeout associated with them, measured
# in terms of a number of ticks. by default a tick is 1000ms, though this can be 
# tuned as desired by the administrator.
#

defmodule Popura.LobbyServ do
  require Logger
  use GenServer
  use Popura.Web, :controller

  import Ecto.Changeset, only: [put_assoc: 3]

  alias Ecto.Multi
  alias Popura.Repo
  alias Popura.Card
  alias Popura.CardPile
  alias Popura.Lobby
  alias Popura.Player

  @target_hand_size 10
  @max_ticks_czar   20
  @max_ticks_player 30
  @max_ticks_win    10

  def start_link(opts \\ []) do
    default_state = %{
      black_card: nil,  # start with no chosen prompt
      czar_id:  nil,    # begin with no czar, nil signals random selection
      czar_idx: nil,
      lobby_id: nil,    # begin with no monitored lobby
      mode: :pick_czar, # game loop starts by choosing a czar
      tick: 0,          # ticks since mode change
      submissions: [],  # submissions in the format {<player id>, [<cards>, ...]}
      winner: {"", []}, # winner name & cards
      winners: [],      # previous winners
    }

    GenServer.start_link(__MODULE__, default_state, opts)
  end

  def init(args), do: {:ok, args}

  defp json_card(card) do
    %{id: card.id, body: card.body, slots: card.slots}
  end

  # returns true or false if all submissions have been
  # established for the round
  defp is_all_submissions_in(state) do
    expected_submissions = 
      Lobby.count_players(from l in Lobby,where: l.id == ^state.lobby_id)
      |> Repo.one

    Enum.count(state.submissions) >= (expected_submissions - 1)
  end

  # mode changes
  # these methods adjust the mode of the lobby, usually based on
  # a timeout or some game logic (e.g: all responses submitted.)

  defp bc_error(ident, msg) do
    response = %{error: msg}
    Popura.Endpoint.broadcast! ident, "announce", response
  end

  defp do_await_responses(state), do: %{state | tick: 0, mode: :wait_players}

  defp do_announce_timeout(state) do
    if state.tick > @max_ticks_win do
      %{state | tick: 0, mode: :pick_czar}
    else
      state
    end
  end

  defp do_czar_timeout(state) do
    no_submissions = state.submissions == []
    czar_timeout   = state.tick > @max_ticks_czar
    cond do
      no_submissions ->
        bc_error(ident(state.lobby_id), """
        There were no submissons in time, so this round ends in a draw.
        """)
        %{state | tick: 0, mode: :announce_winner}

      czar_timeout ->
        bc_error(ident(state.lobby_id), """
        The czar did not make a selection in time. This round ends in a draw.
        """)
        %{state | tick: 0, mode: :announce_winner}
      
      true -> state
    end
  end

  defp do_player_timeout(state) do
    if (state.tick > @max_ticks_player) or (is_all_submissions_in(state)) do
      # ask the czar to pick a thing!
      lobby = Repo.get!(Lobby, state.lobby_id)

      # TODO(hime): cache card bodies to prevent reloading them O(n+1) here ...
      submissions = for {uid, card_ids} <- state.submissions do
        card_ids
        |> Enum.map(fn el -> Repo.get!(Card, el) end)
        |> Enum.map(&json_card/1)
      end

      czar = Repo.one(from p in Player, where: p.id == ^state.czar_id)
      response = %{cards: submissions, czar_id: czar.id, czar_uid: czar.user_id}
      Popura.Endpoint.broadcast! ident(lobby.id), "reveal", response

      %{state | tick: 0, mode: :wait_czar}
    else
      state
    end
  end

  defp do_tick(state) do
    Popura.Endpoint.broadcast! ident(state.lobby_id), "tick", %{tick_no: state.tick, mode: state.mode}
    %{state | tick: (state.tick + 1)}
  end

  # ensure each player has 10 cards
  defp do_deal_players(state) do
    Logger.debug "dealing cards ..."

    lobby = 
      Repo.get!(Lobby, state.lobby_id)
      |> Repo.preload([:players])

    white_cards =
      from(lc in CardPile,
      where: lc.lobby_id == ^lobby.id and lc.tag == ^Lobby.white_deck)
      |> Repo.all
      |> Enum.shuffle


    lobby.players
    |> Enum.reject(fn (player) -> player.id == state.czar_id end)
    |> List.foldl(white_cards, fn (player, white_cards) ->
      # load the player cards (TODO: preload earlier?)
      hand = player |> Repo.preload([:cards])

      # count cards and take number to replenish
      total_cards   = Enum.count(hand.cards)
      missing_cards = @target_hand_size - total_cards
      {taken,left}  = Enum.split(white_cards, missing_cards)

      taken_ids = Enum.map(taken, fn el -> el.card_id end)
      taken_assigns = Enum.map(taken, fn el -> [card_id: el.card_id, player_id: player.id] end)

      lobby_cards = from(
        lc in CardPile,
        where:
          lc.lobby_id == ^lobby.id
          and lc.tag  == ^Lobby.white_deck
          and lc.card_id in ^taken_ids)


      Repo.update_all(lobby_cards, set: [lobby_id: nil, player_id: player.id])
      Logger.info "player hand dealt OK"

      hand =
        player
        |> Repo.preload([:cards])
        |> Repo.preload([cards: :card])

      hand_descriptor =
        hand.cards
        |> Enum.map(fn el -> el.card end)
        |> Enum.map(&json_card/1)

      Logger.warn "inspecting hand descriptor: #{inspect hand_descriptor}"

      # announce player's hand to them ...
      prompt_card = json_card(state.black_card.card)
      response = %{cards: hand_descriptor, prompt: prompt_card, target: player.user_id}
      Popura.Endpoint.broadcast! ident(lobby.id), "deal", response

      left
    end)

    state
  end

  # selects black card and czar
  defp do_pick_czar(state) do
    lobby = Repo.get!(Lobby, state.lobby_id)
    |> Repo.preload([:players])

    # deal black card ...
    black_card = Repo.all(from lc in CardPile, where: lc.lobby_id == ^lobby.id and lc.tag == ^Lobby.black_deck)
    |> Enum.shuffle |> List.first
    |> CardPile.changeset(%{tag: Lobby.black_discard})
    |> Repo.update! |> Repo.preload([:card])

    # select from the array in a wrapping fashion
    czar_len = Enum.count(lobby.players)
    czar_idx = if is_nil(state.czar_idx), do: 0, else: rem((state.czar_idx+1), czar_len)
    czar = Enum.at(lobby.players, czar_idx)

    # build scoreboards
    scoreboard = for player <- lobby.players, into: %{} do
      total_won = 
        Enum.filter(state.winners, fn {id,_entry} -> id == player.id end)
        |> Enum.count

      {player.name, %{rounds_won: total_won, is_czar: (player.id == czar.id)}}
    end

    Popura.Endpoint.broadcast! ident(lobby.id), "score", scoreboard

    # build czar prompt ui
    response = %{target: czar.user_id, prompt: json_card(black_card.card)}
    Popura.Endpoint.broadcast! ident(lobby.id), "czar", response

    %{state | black_card: black_card, czar_id: czar.id, czar_idx: czar_idx, submissions: []}
  end

  def handle_info(:tick, state) do
    state = case state.mode do
      :pick_czar ->
        state
        |> do_pick_czar()
        |> do_deal_players()
        |> do_await_responses()

      :wait_players ->
        state
        |> do_player_timeout()

      :wait_czar ->
        state
        |> do_czar_timeout()

      :announce_winner ->
        state
        |> do_announce_timeout()

    end

    Process.send_after(self(), :tick, 1000)
    {:noreply, do_tick(state)}
  end

  def handle_call({:ping, lobby_id}, _from, state) do
    Popura.Endpoint.broadcast! ident(lobby_id), "oobping", %{}
    {:reply, :pong, state}
  end

  def handle_call({:start, lobby_id}, _from, state) do
    # first check that we can acquire a lobby lock    
    lobby = Repo.get!(Lobby, lobby_id)

    if lobby.serv_lock do
      error = {:error, "Cannot start the game, another LobbyServ has locked this lobby!"}
      {:reply, error, state}
    else
      changeset = Lobby.changeset(lobby, %{serv_lock: true}) |> Repo.update!
      Process.send_after(self(), :tick, 1000)
      {:reply, :ok, %{state | lobby_id: lobby.id}}
    end
  end

  def handle_call({:winner, user_id, choices}, _from, state) do
    # first we need to figure out who won...
    choices = choices |> Enum.map(&String.to_integer/1)
    winner_id = List.foldl(state.submissions, nil, fn {uid,cards}, acc ->
      acc || (if Enum.sort(cards) == Enum.sort(choices), do: uid, else: nil)
    end)

    Logger.debug "picking winner: #{inspect winner_id}"
    winner  = Repo.one(
      from p in Player, 
      where: p.user_id == ^winner_id
      and p.lobby_id == ^state.lobby_id
    )

    choices = choices
      |> Enum.map(fn el -> Repo.get!(Card, el) end)
      |> Enum.map(&json_card/1)

    # announce the winner
    response = %{winner: winner.name, choices: choices}
    Popura.Endpoint.broadcast! ident(state.lobby_id), "announce", response

    # store the winner
    # change state to announce winner phase
    state = state
      |> Map.merge(%{tick: 0, mode: :announce_winner})
      |> Map.merge(%{winner: {winner.name, choices}})
      |> Map.merge(%{winners: [{winner.id, choices} | state.winners]})

    # enter announce timeout
    {:reply, :ok, state}
  end

  def handle_call({:submit, user_id, choices}, _from, state) do
    # load choices, in order, from database
    Logger.debug "user #{inspect user_id} submitted #{inspect choices}"
    lobby  = Repo.one(from l in Lobby, where: l.id == ^state.lobby_id)
    player = Repo.one(from p in Player, where: p.lobby_id == ^state.lobby_id and p.user_id == ^user_id)

    # store the submission in the lobby's non-persistent staging area
    choices = Enum.map(choices, &String.to_integer/1)
    state = Map.put(state, :submissions, [{user_id, choices} | state.submissions])

    # move their choices to the lobbie's white discard pile
    Logger.debug "moving selected cards to discard => #{inspect choices}"
    player_discards = 
      from cp in CardPile,
      where: cp.player_id == ^player.id
      and cp.card_id in ^choices

    Repo.update_all(player_discards, set: [lobby_id: lobby.id, tag: Lobby.white_discard])

    # send the current hand back to the player
    player_hand = 
      from cp in CardPile,
      where: cp.player_id == ^player.id

    hand_descriptor = Repo.all(player_hand) 
                      |> Repo.preload(:card)
                      |> Enum.map(fn el -> el.card end) 
                      |> Enum.map(&json_card/1)
    
    response = %{cards: hand_descriptor, target: player.user_id}
    Popura.Endpoint.broadcast! ident(state.lobby_id), "confirm", response

    {:reply, :ok, state}
  end

  defp ident(lobby_id), do: "lobby:#{lobby_id}"
end
