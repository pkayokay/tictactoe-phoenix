defmodule Tictactoe.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :slug, :string, null: false
      add :board, {:array, :string}, default: ["", "", "", "", "", "", "", "", ""]
      add :current_player, :string
      add :status, :string, default: "waiting"
      add :winner, :string
      add :player_x_session, :string
      add :player_o_session, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:games, [:slug])
  end
end
