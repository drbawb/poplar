defmodule Popura.PlayerController do
  use Popura.Web, :controller

  alias Popura.Lobby
  alias Popura.Player

  def index(conn, %{"lobby_id" => lobby_id} = _params) do
    lobby   = Repo.get!(Lobby, lobby_id)
    players = Repo.all(Player)
    render(conn, "index.html", lobby: lobby, players: players)
  end

  def new(conn, %{"lobby_id" => lobby_id} = _params) do
    lobby     = Repo.get!(Lobby, lobby_id)
    changeset = Player.changeset(%Player{})
    render(conn, "new.html", changeset: changeset, lobby: lobby)
  end

  def create(conn, %{"lobby_id" => lobby_id, "player" => player_params} = _params) do
    # check that lobby is OK
    {password,player_params} = Map.pop(player_params, "password")
    lobby      = Repo.get!(Lobby, lobby_id)
    lobby_auth = lobby.password == password

    # set us up the player
    user_id   = get_session(conn, :auth_id)
    player    = %Player{lobby_id: lobby.id, user_id: user_id}
    changeset = Player.changeset(player, player_params)

    # add player to lobby if authorization looks OK
    if lobby_auth do
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
    player = Repo.get!(Player, player_id) |> Repo.delete!

    redirect(conn, to: lobby_player_path(conn, :index, lobby))
  end
end
