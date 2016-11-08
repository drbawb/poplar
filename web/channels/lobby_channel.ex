defmodule Popura.LobbyChannel do
  require Logger
  use Phoenix.Channel
  use Popura.Web, :controller

  def join("lobby:" <> lobby_id, auth, socket) do
    Logger.debug "channel auth => #{inspect auth}"
    {:ok, socket}
  end
end
