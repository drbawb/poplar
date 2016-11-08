# the lobby serv manages the state related to a `lobbies` record
# a game exists in one of several modes:
# 
# - pick_czar    :: the game selects a czar and prompt
# - wait_players :: the game collects player responses
# - wait_czar    :: the game waits for the czar to select a winner
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

  alias Popura.Repo
  alias Popura.Card
  alias Popura.Deck
  alias Popura.DeckCard
  alias Popura.Lobby
  alias Popura.Player

  @target_hand_size 10
  @max_ticks_czar   15
  @max_ticks_player 15

  def start_link(opts \\ []) do
    default_state = %{
      czar_id:  nil,    # begin with no czar, nil signals random selection
      lobby_id: nil,    # begin with no monitored lobby
      mode: :pick_czar, # game loop starts by choosing a czar
      tick: 0,          # ticks since mode change
    }

    GenServer.start_link(__MODULE__, default_state, opts)
  end

  def init(args), do: {:ok, args}

  # utility helpers
  # load game state from DB
  # should probably make an "assigns" type setup

  # load DeckCard pointers for cheap hand rearranging
  defp inflate_white_deck(lobby_id) do
    lobby = Repo.get!(Lobby, lobby_id)
    deck  = Repo.all(from dc in DeckCard, where: dc.deck_id == ^lobby.white_deck_id)
    |> Repo.preload([:card])
  end

  # lod lobby & players
  defp inflate_lobby(lobby_id) do
    lobby = Repo.get!(Lobby, lobby_id) |> Repo.preload([:players, players: :hand])
  end

  # mode changes
  # these methods adjust the mode of the lobby, usually based on
  # a timeout or some game logic (e.g: all responses submitted.)

  defp do_await_responses(state), do: %{state | tick: 0, mode: :wait_players}

  defp do_player_timeout(state) do
    if state.tick > @max_ticks_player do
      %{state | tick: 0, mode: :wait_czar}
    else
      state
    end
  end

  defp do_czar_timeout(state) do
    if state.tick > @max_ticks_czar do
      %{state | tick: 0, mode: :pick_czar}
    else
      state
    end
  end

  defp do_tick(state), do: %{state | tick: (state.tick + 1)}

  # ensure each player has 10 cards
  defp do_deal_players(state, lobby, white_cards) do
    Logger.warn "dealing cards ..."

    # deal black card ...
    black_card = Repo.all(from dc in DeckCard, where: dc.deck_id == ^lobby.black_deck_id)
    |> Enum.shuffle |> List.first
    |> DeckCard.changeset(%{deck_id: lobby.black_discard_id})
    |> Repo.update! |> Repo.preload([:card])

    List.foldl(lobby.players, white_cards, fn (player, white_cards) ->
      # load the player cards
      hand = if player.hand == nil do
        changeset = Player.changeset(player, %{})
        |> put_assoc(:hand, %Deck{})
        |> Repo.update!()
        |> Repo.preload([:hand, hand: :cards])

        changeset.hand
      else
        player.hand |> Repo.preload([:cards])
      end

      # count cards and take number to replenish
      total_cards   = Enum.count(hand.cards)
      missing_cards = @target_hand_size - total_cards
      {taken,left}  = Enum.split(white_cards, missing_cards)

      # swap card pointers
      for card_ptr <- taken do
        DeckCard.changeset(card_ptr, %{deck_id: hand.id})
        |> Repo.update!
      end

      # build json representation of new hand ...
      hand_descriptor =
        Enum.map(hand.cards, fn el -> el.body end) ++
        Enum.map(taken, fn el -> el.card.body end)

      # announce player's hand to them ...
      # TODO: goes to shared lobby ...
      response = %{cards: hand_descriptor, prompt: black_card.card.body, target: player.user_id}
      Popura.Endpoint.broadcast! ident(lobby.id), "hand", response
      left # yield remaining deck for next player
    end)

    state
  end

  defp do_pick_czar(state) do
    state
  end

  def handle_info(:tick, state) do
    state = case state.mode do
      :pick_czar ->
        lobby      = inflate_lobby(state.lobby_id)
        white_deck = inflate_white_deck(state.lobby_id)

        state
        |> do_pick_czar()
        |> do_deal_players(lobby, white_deck)
        |> do_await_responses()

      :wait_players ->
        state
        |> do_player_timeout()

      :wait_czar ->
        state
        |> do_czar_timeout()

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

  def handle_cast({:deal, lobby_id}, state) do
    # select random cards from this lobby ...
    lobby = Repo.get!(Lobby, lobby_id) 
            |> Repo.preload([:white_deck, white_deck: :cards])
            |> Repo.preload([:black_deck, black_deck: :cards])

    prompt = lobby.black_deck.cards
              |> Enum.shuffle
              |> List.first
              |> Map.get(:body)

    cards = lobby.white_deck.cards
            |> Enum.shuffle
            |> Enum.take(10)
            |> Enum.map(fn el -> el.body end)

    Popura.Endpoint.broadcast! ident(lobby_id), "hand", %{cards: cards, prompt: prompt}
    {:noreply, state}
  end

  defp ident(lobby_id), do: "lobby:#{lobby_id}"
end
