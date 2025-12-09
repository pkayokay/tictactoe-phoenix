defmodule Tictactoe.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Tictactoe.Repo
  alias Tictactoe.Games.Game

  @doc """
  Generates a random 6-character slug using alphanumeric characters.
  """
  def generate_slug do
    chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    length = 6

    slug =
      for _ <- 1..length do
        String.at(chars, :rand.uniform(String.length(chars)) - 1)
      end
      |> Enum.join()

    # Ensure uniqueness
    if get_game(slug) do
      generate_slug()
    else
      slug
    end
  end

  @doc """
  Creates a new game with a random slug.
  """
  def create_game do
    slug = generate_slug()

    %Game{}
    |> Game.changeset(%{
      slug: slug,
      board: List.duplicate("", 9),
      status: "waiting"
    })
    |> Repo.insert()
  end

  @doc """
  Gets a single game by slug.
  """
  def get_game(slug) when is_binary(slug) do
    Repo.get_by(Game, slug: slug)
  end

  @doc """
  Joins a game by slug. Returns {:ok, game, role} or {:error, reason}.
  Role can be "X", "O", or "spectator".
  """
  def join_game(slug, session_id) do
    case get_game(slug) do
      nil ->
        {:error, :not_found}

      game ->
        # Check if user is already a player (reconnecting)
        cond do
          game.player_x_session == session_id ->
            {:ok, game, "X"}

          game.player_o_session == session_id ->
            {:ok, game, "O"}

          game.player_x_session == nil ->
            game
            |> Game.changeset(%{
              player_x_session: session_id,
              current_player: "X",
              status: if(game.player_o_session, do: "playing", else: "waiting")
            })
            |> Repo.update()
            |> case do
              {:ok, updated_game} -> {:ok, updated_game, "X"}
              error -> error
            end

          game.player_o_session == nil ->
            game
            |> Game.changeset(%{
              player_o_session: session_id,
              current_player: "X",
              status: "playing"
            })
            |> Repo.update()
            |> case do
              {:ok, updated_game} -> {:ok, updated_game, "O"}
              error -> error
            end

          true ->
            {:ok, game, "spectator"}
        end
    end
  end

  @doc """
  Releases a player slot when they disconnect.
  """
  def release_player_slot(slug, session_id) do
    case get_game(slug) do
      nil ->
        {:error, :not_found}

      game ->
        cond do
          game.player_x_session == session_id ->
            game
            |> Game.changeset(%{
              player_x_session: nil,
              status: if(game.player_o_session, do: "waiting", else: "waiting"),
              current_player: if(game.player_o_session, do: "O", else: nil)
            })
            |> Repo.update()

          game.player_o_session == session_id ->
            game
            |> Game.changeset(%{
              player_o_session: nil,
              status: if(game.player_x_session, do: "waiting", else: "waiting"),
              current_player: if(game.player_x_session, do: "X", else: nil)
            })
            |> Repo.update()

          true ->
            {:ok, game}
        end
    end
  end

  @doc """
  Claims an available player slot. Returns {:ok, game, role} or {:error, reason}.
  """
  def claim_player_slot(slug, session_id, slot) when slot in ["X", "O"] do
    case get_game(slug) do
      nil ->
        {:error, :not_found}

      game ->
        cond do
          slot == "X" and game.player_x_session == nil ->
            game
            |> Game.changeset(%{
              player_x_session: session_id,
              current_player: "X",
              status: if(game.player_o_session, do: "playing", else: "waiting")
            })
            |> Repo.update()
            |> case do
              {:ok, updated_game} -> {:ok, updated_game, "X"}
              error -> error
            end

          slot == "O" and game.player_o_session == nil ->
            game
            |> Game.changeset(%{
              player_o_session: session_id,
              current_player: "X",
              status: "playing"
            })
            |> Repo.update()
            |> case do
              {:ok, updated_game} -> {:ok, updated_game, "O"}
              error -> error
            end

          true ->
            {:error, :slot_not_available}
        end
    end
  end

  @doc """
  Makes a move on the board. Returns {:ok, game} or {:error, changeset}.
  """
  def make_move(slug, position, player) when position in 0..8 and player in ["X", "O"] do
    case get_game(slug) do
      nil ->
        {:error, :not_found}

      game ->
        # Ensure board has 9 elements
        board = ensure_board_length(game.board || [])
        cell_value = Enum.at(board, position)

        cond do
          game.status != "playing" ->
            {:error, :game_not_playing}

          game.current_player != player ->
            {:error, :not_your_turn}

          cell_value != nil and cell_value != "" ->
            {:error, :cell_occupied}

          true ->
            # Update board
            new_board = List.replace_at(board, position, player)

            # Check for winner or draw
            winner = check_winner(new_board)
            draw = if winner == nil, do: check_draw(new_board), else: false

            status = cond do
              winner != nil -> "finished"
              draw -> "finished"
              true -> "playing"
            end

            winner_value = cond do
              winner != nil -> winner
              draw -> "draw"
              true -> nil
            end

            # Update current player if game continues
            next_player = if status == "playing", do: if(player == "X", do: "O", else: "X"), else: nil

            game
            |> Game.changeset(%{
              board: new_board,
              current_player: next_player,
              status: status,
              winner: winner_value
            })
            |> Repo.update()
        end
    end
  end

  @doc """
  Checks if there's a winner on the board.
  Returns "X", "O", or nil.
  """
  def check_winner(board) do
    winning_combinations = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], # rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], # columns
      [0, 4, 8], [2, 4, 6]              # diagonals
    ]

    Enum.find_value(winning_combinations, fn [a, b, c] ->
      cell_a = Enum.at(board, a)
      cell_b = Enum.at(board, b)
      cell_c = Enum.at(board, c)

      if cell_a != nil and cell_a != "" and cell_a == cell_b and cell_b == cell_c do
        cell_a
      else
        nil
      end
    end)
  end

  @doc """
  Checks if the game is a draw (board full, no winner).
  """
  def check_draw(board) do
    length(board) == 9 and
      Enum.all?(board, fn cell -> cell != nil and cell != "" end) and
      check_winner(board) == nil
  end

  defp ensure_board_length(board) when is_list(board) and length(board) == 9, do: board
  defp ensure_board_length(board) when is_list(board), do: board ++ List.duplicate("", 9 - length(board))
  defp ensure_board_length(_), do: List.duplicate("", 9)
end
