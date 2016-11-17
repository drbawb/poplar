defmodule Popura.LobbyController do
  require Logger

  use Popura.Web, :controller

  import Ecto.Changeset, only: [put_change: 3, put_assoc: 3]
  alias Ecto.Multi
  alias Popura.Card
  alias Popura.CardPile
  alias Popura.Deck 
  alias Popura.Lobby
  alias Popura.Player

  def can?(conn, verb, resource) do
    auth_id = get_session(conn, :auth_id)
    is_authorized = _authrule(auth_id, verb, resource)

    if not is_authorized do
      conn
      |> put_flash(:error, "You cannot do that, since you do not own that lobby.")
      |> redirect(to: lobby_path(conn, :index))
      |> halt
    end

    is_authorized
  end

  defp _authrule(id, update, %Lobby{owner_id: owner} = lobby)
  when update in [:new, :create], do: not is_nil(id)

  defp _authrule(id, update, %Lobby{owner_id: owner} = lobby)
  when update in [:edit, :update, :delete], do: owner == id

  defp _authrule(id, action, model), do: false

  def index(conn, _params) do
    lobbies = Repo.all(Lobby)
    render(conn, "index.html", lobbies: lobbies)
  end

  def new(conn, _params) do
    changeset = Lobby.changeset(%Lobby{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"lobby" => lobby_params}) do
    user_id = get_session(conn, :auth_id)
    lobby_params = lobby_params |> Map.merge(%{"owner_id" => user_id})
    
    # preload selected decks ...
    {deck_id,lobby_params} = Map.pop(lobby_params, "deck_id")
    all_cards = Repo.get!(Deck, deck_id) |> Repo.preload([:cards])

    # build the lobby
    changeset = Lobby.changeset(%Lobby{}, lobby_params)

    # create lobby & assign decks atomically
    multi = 
      Ecto.Multi.new
      |> Ecto.Multi.insert(:lobby, changeset)
      |> Ecto.Multi.run(:cards, fn changeset -> 
        lobby_id = changeset.lobby.id
        cards = all_cards.cards |> Enum.map(fn el ->
          tag = if el.slots > 0, do: Lobby.black_deck, else: Lobby.white_deck
          [card_id: el.id, lobby_id: lobby_id, tag: tag]
        end)

        {count, _records} = Repo.insert_all(CardPile, cards)
        {:ok, count}
      end)

    case Repo.transaction(multi) do
      {:ok, %{lobby: _lobby, cards: _cards}} ->
        conn
        |> put_flash(:info, "Lobby created successfully.")
        |> redirect(to: lobby_path(conn, :index))

      {:error, :lobby, changeset, _prior} ->
        Logger.warn "TXN Error building lobby"
        render(conn, "new.html", changeset: changeset)

      {:error, key, reason, _prior} ->
        Logger.warn "TXN Error [#{inspect key}] => #{inspect reason}"

        conn
        |> put_flash(:error, "There was an error loading the selected deck. Please bug an admin.")
        |> render("new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    user_id = get_session(conn, :auth_id)
    player  = Repo.one(from p in Player, where: p.user_id == ^user_id and p.lobby_id == ^id)

    if player == nil do
      conn
      |> put_flash(:info, "You are not a member of that lobby.")
      |> redirect(to: lobby_path(conn, :index))
    else
      token = Phoenix.Token.sign(Popura.Endpoint, "user", user_id)
      lobby = Repo.get!(Lobby, id) 
              |> Repo.preload([:players, :cards])

      render(conn, "show.html", lobby: lobby, token: token, is_admin: (user_id == lobby.owner_id))
    end
  end

  def edit(conn, %{"id" => id}) do
    user_id = get_session(conn, :auth_id)
    lobby = Repo.get!(Lobby, id)
    can?(conn, :edit, lobby)

    changeset = Lobby.changeset(lobby)
    render(conn, "edit.html", lobby: lobby, changeset: changeset)
  end

  def update(conn, %{"id" => id, "lobby" => lobby_params}) do
    lobby = Repo.get!(Lobby, id)
    changeset = Lobby.changeset(lobby, lobby_params)
    can?(conn, :update, lobby)

    case Repo.update(changeset) do
      {:ok, lobby} ->
        conn
        |> put_flash(:info, "Lobby updated successfully.")
        |> redirect(to: lobby_path(conn, :show, lobby))
      {:error, changeset} ->
        render(conn, "edit.html", lobby: lobby, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    lobby = Repo.get!(Lobby, id)
    
    if can?(conn, :delete, lobby) do
      Repo.delete!(lobby)
      
      conn
      |> put_flash(:info, "Lobby deleted successfully.")
      |> redirect(to: lobby_path(conn, :index))
    else
      conn
    end
  end


  # TODO(hime): non-standard actions for controlling associated LobbyServ

  @doc """
  Starts a LobbyServ in the global namespace if possible.
  """
  def start(conn, %{"id" => id} = _params) do
    lobby = Repo.get!(Lobby, id)
    ident = "lobby:#{lobby.id}"

    # start a process to monitor this lobby
    Popura.LobbyServ.start_link [name: {:global, ident}]

    # instruct it to start handling events from WS transports
    case GenServer.call({:global, ident}, {:start, lobby.id}) do
      :ok ->
        conn
        |> put_flash(:info, "Server started up")
        |> redirect(to: lobby_path(conn, :show, lobby))       

      {:error, msg} ->
        conn
        |> put_flash(:error, "Could not start server: #{inspect msg}")
        |> redirect(to: lobby_path(conn, :show, lobby))
    end
  end

  def stop(conn, %{"id" => id} = _params) do
    lobby = Repo.get!(Lobby, id)
    ident = "lobby:#{lobby.id}"

    status = GenServer.stop({:global, ident})

    status = lobby
    |> Lobby.changeset
    |> put_change(:serv_lock, false)
    |> Repo.update

    case status do
      {:ok, _lobby} ->
        conn
        |> put_flash(:info, "Server stopped ok and unlocked")
        |> redirect(to: lobby_path(conn, :show, lobby))

      {:error, msg} ->
        conn
        |> put_flash(:error, "Server could not stop because: #{inspect msg}")
        |> redirect(to: lobby_path(conn, :show, lobby))
    end
  end

  # destroys current deck(s) and rebuilds them
  def reset(conn, %{"id" => id} = _params) do
    lobby = Repo.one(Lobby.with_decks(from l in Lobby, where: l.id == ^id))
    player_ids = Repo.all(from l in Lobby, join: p in assoc(l, :players), select: p.id)
    Logger.warn "loaded lobby :: #{inspect lobby}"
    Logger.warn "also resetting players :: #{inspect player_ids}"

    # move discards back to normal decks
    # TODO(hime): doesn't perma-discard winning submissions
    black_discards = 
      from lc in CardPile,
      where: lc.lobby_id == ^lobby.id and lc.tag == ^Lobby.black_discard

    white_discards = 
      from(lc in CardPile,
      where: (lc.lobby_id == ^lobby.id and lc.tag == ^Lobby.white_discard)
      or (lc.player_id in ^player_ids))

    Logger.warn inspect(Ecto.Adapters.SQL.to_sql(:all, Repo, white_discards))

    Repo.update_all(black_discards, set: [tag: Lobby.black_deck])
    Repo.update_all(white_discards, set: [tag: Lobby.white_deck, lobby_id: lobby.id, player_id: nil])

    conn |> redirect(to: lobby_path(conn, :show, lobby))
  end
end
