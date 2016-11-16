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
