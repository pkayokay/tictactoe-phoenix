defmodule Tictactoe.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :slug, :string
    field :board, {:array, :string}, default: ["", "", "", "", "", "", "", "", ""]
    field :current_player, :string
    field :status, :string, default: "waiting"
    field :winner, :string
    field :player_x_session, :string
    field :player_o_session, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:slug, :board, :current_player, :status, :winner, :player_x_session, :player_o_session])
    |> validate_required([:slug])
    |> validate_inclusion(:status, ["waiting", "playing", "finished"])
    |> validate_inclusion(:current_player, ["X", "O"], message: "must be X or O")
    |> validate_inclusion(:winner, [nil, "X", "O", "draw"], message: "must be X, O, or draw")
    |> unique_constraint(:slug)
  end
end
