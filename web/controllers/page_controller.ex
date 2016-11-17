defmodule Popura.PageController do
  use Popura.Web, :controller

  alias Popura.Lobby

  def index(conn, _params) do
    lobbies = Repo.all(from l in Lobby)
    render conn, "index.html", lobbies: lobbies
  end
end
