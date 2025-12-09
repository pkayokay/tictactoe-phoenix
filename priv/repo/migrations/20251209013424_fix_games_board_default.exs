defmodule Tictactoe.Repo.Migrations.FixGamesBoardDefault do
  use Ecto.Migration

  def up do
    # Update existing games with empty boards
    execute "UPDATE games SET board = ARRAY['','','','','','','','','']::text[] WHERE array_length(board, 1) IS NULL"

    # Change the default for new records
    alter table(:games) do
      modify :board, {:array, :string}, default: fragment("ARRAY['','','','','','','','','']::text[]")
    end
  end

  def down do
    alter table(:games) do
      modify :board, {:array, :string}, default: []
    end
  end
end
