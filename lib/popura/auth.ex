defmodule Popura.Auth do
  import Plug.Conn
  require Logger

  def init(opts \\ []), do: opts

  def call(conn, _opts) do
    conn |> assign_uuid
  end

  defp assign_uuid(conn) do
    # fetch or generate UUIDv4
    auth_id = get_session(conn, :auth_id) || Ecto.UUID.generate()

    # store in session & assigns
    conn
    |> put_session(:auth_id, auth_id)
    |> assign(:auth_id, auth_id)
  end
end
