defmodule Popura.WhiteCardTest do
  use Popura.ModelCase

  alias Popura.WhiteCard

  @valid_attrs %{body: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = WhiteCard.changeset(%WhiteCard{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = WhiteCard.changeset(%WhiteCard{}, @invalid_attrs)
    refute changeset.valid?
  end
end
