defmodule Popura.Repo.Migrations.CreatekCard do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :body,  :string
      add :slots, :integer

      timestamps()
    end
  end
end
