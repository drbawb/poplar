defmodule Popura.Util do
  alias Popura.Repo
  alias Popura.Lobby
  alias Popura.Card
  alias Popura.Deck
  alias Popura.DeckCard
  
  import Ecto
  import Ecto.Query 
  import Ecto.Changeset, only: [put_assoc: 3, put_change: 3]
  require Logger

  @black_path "priv/questions.txt"
  @white_path "priv/answers.txt"

  def load_cards() do
    Logger.debug "loading card DBs"
    qbuf = File.read!(@black_path)
    abuf = File.read!(@white_path)

    black_no = qbuf |> String.split("\n") |> Enum.count
    white_no = abuf |> String.split("\n") |> Enum.count

    Logger.debug "card DB lines, black => #{black_no}, white => #{white_no}"

    fab_black = for body <- (qbuf |> String.split("\n")) do
      num_underscores = 
        body
        |> String.codepoints()
        |> List.foldl(0, fn el,st -> if el == "_", do: (st+1), else: (st+0) end)
        |> max(1)

      Card.changeset(%Card{}, %{"body" => body, "slots" => num_underscores})
    end

    fab_white = for body <- (abuf |> String.split("\n")) do
      Card.changeset(%Card{}, %{"body" => body, "slots" => 0})
    end

    Logger.debug "black card prefabs :: #{inspect(fab_black |> Enum.count)}"
    Logger.debug "white card prefabs :: #{inspect(fab_white |> Enum.count)}"
    Logger.debug "beginning write to database!"

    # commit all cards in one transaction
    black_count = Enum.map(fab_black, &Repo.insert/1)
    |> Enum.filter(fn {status,_} -> status == :ok end)
    |> Enum.count

    Logger.debug "black res ok... #{black_count}"

    white_count = Enum.map(fab_white, &Repo.insert/1)
    |> Enum.filter(fn {status,_} -> status == :ok end)
    |> Enum.count

    Logger.debug "white res ok... #{white_count}"
  end


  # takes a deck of black/white cards and sorts
  # them intop iles for a lobby
  def build_decks(deck_id, lobby_id) do
    full_deck  = Repo.all(from d in Deck,  preload: :cards, where: d.id == ^deck_id) |> List.first
    black_deck = full_deck.cards |> Enum.filter(fn el -> el.slots >  0 end)
    white_deck = full_deck.cards |> Enum.filter(fn el -> el.slots == 0 end)

    white_pile = Repo.insert!(%Deck{cards: white_deck})
    black_pile = Repo.insert!(%Deck{cards: black_deck})
    white_disc = Repo.insert!(%Deck{cards: []})
    black_disc = Repo.insert!(%Deck{cards: []})

    lobby = Repo.all(from l in Lobby, 
      preload: [:black_deck, :black_discard, :white_deck, :white_discard]) |> List.first

    Lobby.changeset(lobby)
    |> put_assoc(:black_deck, black_pile)
    |> put_assoc(:white_deck, white_pile)
    |> put_assoc(:black_discard, black_disc)
    |> put_assoc(:white_discard, white_disc)
    |> Repo.update!


    Logger.debug "done loading decks to lobby ..."
  end

  # quickly (?) copies a list of card IDs into a new deck
  # then returns that deck...
  def copy_cards(card_ids) when is_list(card_ids) do
    new_deck = Deck.changeset(%Deck{}, %{name: "sys"})
    |> Repo.insert!()

    records = Enum.map(card_ids, fn el -> [deck_id: new_deck.id, card_id: el] end)
    Repo.insert_all(DeckCard, records)

    new_deck
  end

  @doc "Boot a lobby"
  def boot(lobby_id) do
    lpid = {:global, "lobby:#{lobby_id}"}
    {:ok, _} = Popura.LobbyServ.start_link([name: lpid])
    GenServer.call lpid, {:start, lobby_id}
  end

  @doc "Forcibly unlocks a lobby."
  def reset(lobby_id) do
    lobby = Repo.get!(Lobby, lobby_id)
    |> Lobby.changeset
    |> put_change(:serv_lock, false)
    |> Repo.update
  end
end
