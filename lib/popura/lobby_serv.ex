defmodule Popura.LobbyServ do
  require Logger
  use GenServer
  use Popura.Web, :controller

  alias Popura.Repo
  alias Popura.Card
  alias Popura.Deck
  alias Popura.Lobby

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args), do: {:ok, args}

  def handle_info({:tick, tick_no}, state) do
    {:noreply, state}
  end

  def handle_call({:ping, lobby_id}, _from, state) do
    Popura.Endpoint.broadcast! ident(lobby_id), "oobping", %{}
    {:reply, :pong, state}
  end

  def handle_call({:start, lobby_id}, state) do
    
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
