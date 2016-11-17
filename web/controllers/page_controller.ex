defmodule Popura.PageController do
  use Popura.Web, :controller

  alias Popura.Player

  def index(conn, _params) do
    changeset = Player.changeset(%Player{})
    render conn, "index.html", guest: changeset
  end
end
