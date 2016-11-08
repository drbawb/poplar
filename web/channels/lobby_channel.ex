defmodule Popura.LobbyChannel do
  require Logger
  use Popura.Web, :controller
  use Phoenix.Channel

  intercept ["confirm", "deal"]

  def join("lobby:" <> lobby_id, auth, socket) do
    Logger.debug "channel auth => #{inspect auth}"
    {:ok, socket}
  end

  def handle_in("pick", msg, socket) do
    auth_id = socket.assigns[:auth_id]
    %{"choices" => choices} = msg
    Logger.debug "socket(#{auth_id}) picking cards :: #{inspect choices}"

    GenServer.call {:global, socket.topic}, {:submit, auth_id, choices}
    {:noreply, socket}
  end

  def handle_out("deal" = tag, %{target: target_id} = msg, socket) do
    auth_id = socket.assigns[:auth_id]
    Logger.debug "socket hand :: target(#{target_id}), actual(#{auth_id})"

    if target_id == auth_id do
      push(socket, tag, msg)
    end

    {:noreply, socket}
  end

  def handle_out("confirm" = tag, %{target: target_id} = msg, socket) do
    auth_id = socket.assigns[:auth_id]
    Logger.debug "socket hand :: target(#{target_id}), actual(#{auth_id})"

    if target_id == auth_id do
      push(socket, tag, msg)
    end

    {:noreply, socket}
  end
end
