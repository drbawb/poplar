defmodule Popura.LobbyTest do
  use Popura.ModelCase

  alias Popura.Lobby

  @valid_attrs %{name: "some content", owner_id: "7488a646-e31f-11e4-aace-600308960662", password: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Lobby.changeset(%Lobby{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Lobby.changeset(%Lobby{}, @invalid_attrs)
    refute changeset.valid?
  end
end
