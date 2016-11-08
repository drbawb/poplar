defmodule Popura.BlackCardTest do
  use Popura.ModelCase

  alias Popura.BlackCard

  @valid_attrs %{body: "some content", slots: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = BlackCard.changeset(%BlackCard{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = BlackCard.changeset(%BlackCard{}, @invalid_attrs)
    refute changeset.valid?
  end
end
