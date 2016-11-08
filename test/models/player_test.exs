defmodule Popura.PlayerTest do
  use Popura.ModelCase

  alias Popura.Player

  @valid_attrs %{name: "some content", user_id: "7488a646-e31f-11e4-aace-600308960662"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Player.changeset(%Player{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Player.changeset(%Player{}, @invalid_attrs)
    refute changeset.valid?
  end
end
