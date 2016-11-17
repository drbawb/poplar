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

  @moduledoc """
  This module is useful for development and administration of the
  poplar card server.

  This includes facilities for loading plaintext card DBs,
  fixing up bad decks, copying cards to decks, etc.
  """


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

  @doc """
  Loads a deck from the cardcastgame.com API (v1) by using
  the provided five digit shortcode.
  """
  def load_cast(playcode) do
    api   = "https://api.cardcastgame.com/v1"
    deck  = api <> "/decks/" <> playcode
    cards = deck <> "/cards"

    deck  = HTTPoison.get!(deck).body  |> Poison.decode!
    cards = HTTPoison.get!(cards).body |> Poison.decode!

    black = cards["calls"]
    white = cards["responses"]
   
    {:ok, pdeck} = Deck.changeset(%Deck{name: deck["name"]}) |> Repo.insert
    black = for card <- black do
      num_slots = Enum.count(card["text"]) - 1
      body = card["text"] |> Enum.join(" _ ")
      Card.changeset(%Card{deck_id: pdeck.id, body: body, slots: num_slots})
      |> Repo.insert!
    end

    white = for card <- white do
      body = card["text"] |> List.first
      Card.changeset(%Card{deck_id: pdeck.id, body: body, slots: 0})
      |> Repo.insert!
    end
  end

  @doc """
  Loads a CSV that is provided in the following format:

  H Deck Title,Copyright
  H White,     Black
  <white>, <black>,
  ...

  Each black card must contain some number of underscores delimited
  by whitespace or other punctuation.
  """
  def load_csv(path) do
    {headres, records} =
      File.stream!(path) 
      |> CSV.decode
      |> Enum.map(fn row -> row end)
      |> Enum.split(2)

    blank_pattern = ~r/\_+/
    cards = List.foldl(records, %{black: [], white: []}, fn [white,black],st ->
      st = if not(white == "") do
        Map.put(st, :white, [%Card{body: white, slots: 0} | st.white])
      else st end

      st = if not(black == "") do
        fragments = String.split(black, blank_pattern)
        num_slots = Enum.count(fragments) - 1
        body_text = Enum.join(fragments, " _ ")
        Map.put(st, :black, [%Card{body: body_text, slots: num_slots} | st.black])
      else st end
    end)
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

  def fix_html_ents(deck_id) do
    deck = 
      (from d in Deck, where: d.id == ^deck_id,
      join: c in assoc(d, :cards),
      preload: [cards: c]) |> Repo.one

      bad_cards = Enum.filter(deck.cards, &String.contains?(&1.body, "&#"))
      Logger.debug "#{Enum.count bad_cards} bad cards ..."

      for card <- bad_cards do
        fixed = card.body
        |> String.replace("&#34;", "\"")
        |> String.replace("&#174;", "®")

        card
        |> Card.changeset
        |> put_change(:body, fixed)
        |> Repo.update
      end

  end
end
