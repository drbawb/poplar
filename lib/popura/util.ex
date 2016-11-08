defmodule Popura.Util do
  alias Popura.Repo
  alias Popura.Lobby
  alias Popura.Card
  alias Popura.Deck
  
  import Ecto
  import Ecto.Query 
  import Ecto.Changeset, only: [put_assoc: 3]
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
    full_deck  = Repo.get!(Deck, deck_id)
    lobby      = Repo.get!(Lobby, lobby_id)
    black_deck = full_deck |> Enum.filter(fn el -> el.slots >  0 end)
    white_deck = full_deck |> Enum.filter(fn el -> el.slots == 0 end)

    white_pile = Repo.insert!(%Deck{cards: white_deck})
    black_pile = Repo.insert!(%Deck{cards: black_deck})
    white_disc = Repo.insert!(%Deck{cards: []})
    black_disc = Repo.insert!(%Deck{cards: []})

    lobby 
    |> preload([:black_deck, :white_deck, :black_discard, :white_discard])
    |> put_assoc(:black_deck, black_pile)
    |> put_assoc(:white_deck, white_pile)
    |> put_assoc(:black_discard, black_disc)
    |> put_assoc(:white_discard, white_disc)

    Logger.debug "done loading decks to lobby ..."
  end

end
