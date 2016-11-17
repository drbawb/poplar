defmodule Popura.PlayerController do
  use Popura.Web, :controller

  require Logger

  alias Popura.Lobby
  alias Popura.Player

  def can?(conn, verb, resource) do
    auth_id = get_session(conn, :auth_id)
    is_authorized = _authrule(auth_id, verb, resource)

    if not is_authorized do
      conn
      |> put_flash(:error, "You do not have permission to do that.")
      |> redirect(to: lobby_path(conn, :index))
      |> halt
    end

    is_authorized
  end

  defp _authrule(id, verb, %Lobby{owner_id: owner} = lobby)
  when verb in [:new, :create] do

    player_is_not_blank = not is_nil(id)
    player_is_present =
      lobby
      |> Repo.preload(:players)
      |> Map.get(:players)
      |> Enum.map(fn el -> el.user_id end)
      |> Enum.any?(fn el -> el == id end)

    Logger.warn "auth: pblank #{inspect player_is_not_blank}, ppres #{inspect player_is_present}"
    player_is_not_blank and not player_is_present
  end

  defp _authrule(id, verb, %Player{lobby: lobby} = player)
  when verb in [:edit, :update, :delete] do
    player_owns_lobby = id == lobby.owner_id
    player_owns_self  = id == player.user_id

    player_owns_lobby or player_owns_self
  end

  defp _authrule(id, verb, model), do: false

  def index(conn, %{"lobby_id" => lobby_id} = _params) do
    lobby   = Repo.get!(Lobby, lobby_id) |> Repo.preload(:players)
    players = lobby.players
    render(conn, "index.html", lobby: lobby, players: players)
  end

  def new(conn, %{"lobby_id" => lobby_id} = _params) do
    lobby = Repo.get!(Lobby, lobby_id)
    can?(conn, :new, lobby)

    changeset = Player.changeset(%Player{})
    render(conn, "new.html", changeset: changeset, lobby: lobby)
  end

  def create(conn, %{"lobby_id" => lobby_id, "player" => player_params} = _params) do
    # check that lobby is OK
    {password,player_params} = Map.pop(player_params, "password")
    lobby      = Repo.get!(Lobby, lobby_id)
    lobby_auth = lobby.password == password

    user_id   = get_session(conn, :auth_id)
    player    = %Player{lobby_id: lobby.id, user_id: user_id}
    changeset = Player.changeset(player, player_params)

    # add player to lobby if authorization looks OK
    if can?(conn, :create, lobby) and lobby_auth do
      case Repo.insert(changeset) do
        {:ok, _player} ->
          conn
          |> put_flash(:info, "Player is make. GOOD JOB!")
          |> redirect(to: lobby_path(conn, :show, lobby))

        {:error, changeset} ->
          render(conn, "new.html", changeset: changeset, lobby: lobby)
      end
    else
      conn
      |> put_flash(:info, "You are fuckup. That no right password.")
      |> render("new.html", changeset: changeset, lobby: lobby)
    end
  end

  def delete(conn, %{"lobby_id" => lobby_id, "id" => player_id} = _params) do
    lobby  = Repo.get!(Lobby, lobby_id)
    player = Repo.get!(Player, player_id) |> Repo.preload(:lobby)

    if can?(conn, :delete, player) do
      Repo.delete!(player)
      redirect(conn, to: lobby_player_path(conn, :index, lobby))
    end
  end
end
