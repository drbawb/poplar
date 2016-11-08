defmodule Popura.DeckTest do
  use Popura.ModelCase

  alias Popura.Deck

  @valid_attrs %{name: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Deck.changeset(%Deck{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Deck.changeset(%Deck{}, @invalid_attrs)
    refute changeset.valid?
  end
end
