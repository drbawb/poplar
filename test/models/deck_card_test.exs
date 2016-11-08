defmodule Popura.DeckCardTest do
  use Popura.ModelCase

  alias Popura.DeckCard

  @valid_attrs %{}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = DeckCard.changeset(%DeckCard{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = DeckCard.changeset(%DeckCard{}, @invalid_attrs)
    refute changeset.valid?
  end
end
