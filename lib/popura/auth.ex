defmodule Popura.Auth do
  import Plug.Conn
  require Logger

  def init(opts \\ []),  do: opts
  def call(conn, _opts), do: conn |> assign_uuid

  defp assign_uuid(conn) do
    # fetch or generate UUIDv4
    auth_id = fetch_uuid(conn) || Ecto.UUID.generate()

    # store in session & assigns
    # notes that we have setup a consistent auth profile
    # for this player... this enables them to administer
    # their own lobbies ...
    conn
    |> put_session(:auth_id, auth_id)
    |> put_session(:auth_role, [:player])
    |> assign(:auth_id, auth_id)
  end

  defp fetch_uuid(conn), do: get_session(conn, :auth_id)
  defp fetch_role(conn), do: get_session(conn, :auth_role)
end
