defmodule Popura.Repo.Migrations.CreateDeck do
  use Ecto.Migration

  def change do
    create table(:decks) do
      add :name, :string

      timestamps()
    end

  end
end
