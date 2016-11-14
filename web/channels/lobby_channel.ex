defmodule Popura.LobbyChannel do
  require Logger
  use Popura.Web, :controller
  use Phoenix.Channel

  intercept ["confirm", "czar", "deal", "reveal"]

  def join("lobby:" <> lobby_id, auth, socket) do
    Logger.debug "channel auth => #{inspect auth}"
    {:ok, socket}
  end

  # handles the czar declaring a winner...
  def handle_in("declare", msg, socket) do
    auth_id = socket.assigns[:auth_id]
    %{"choices" => choices} = msg
    Logger.debug "socket(#{auth_id}) picking winner :: #{inspect choices}"
    GenServer.call {:global, socket.topic}, {:winner, auth_id, choices}
    {:noreply, socket}
  end

  # handles the player declaring a submission
  def handle_in("pick", msg, socket) do
    auth_id = socket.assigns[:auth_id]
    %{"choices" => choices} = msg
    Logger.debug "socket(#{auth_id}) picking cards :: #{inspect choices}"

    GenServer.call {:global, socket.topic}, {:submit, auth_id, choices}
    {:noreply, socket}
  end

  def handle_out("czar" = tag, %{target: target_id} = msg, socket) do
    push_id(socket, target_id, tag, msg)
    {:noreply, socket}
  end

  def handle_out("deal" = tag, %{target: target_id} = msg, socket) do
    push_id(socket, target_id, tag, msg)
    {:noreply, socket}
  end

  def handle_out("confirm" = tag, %{target: target_id} = msg, socket) do
    push_id(socket, target_id, tag, msg)
    {:noreply, socket}
  end

  def handle_out("reveal" = tag, %{czar_uid: czar_uid} = msg, socket) do
    auth_id = socket.assigns[:auth_id]
    msg = Map.put(msg, :is_czar, (auth_id == czar_uid))
    push(socket, tag, msg )
    {:noreply, socket}
  end

  defp push_id(socket, id, tag, msg) do
    auth_id = socket.assigns[:auth_id]
    if id == auth_id, do: push(socket, tag, msg)
  end
end
