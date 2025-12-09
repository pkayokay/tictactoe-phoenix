defmodule TictactoeWeb.GameLive.Show do
  use TictactoeWeb, :live_view

  alias Tictactoe.Games

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Games.get_game(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found")
         |> push_navigate(to: ~p"/")}

      game ->
        game_assigns = game_to_assigns(game)
        # Ensure board is always a list of 9 elements
        game_assigns = %{game_assigns | board: ensure_board_list(game_assigns.board)}

        {:ok,
         socket
         |> assign(:slug, slug)
         |> assign(:game, game_assigns)
         |> assign(:role, nil)
         |> assign(:channel_connected, false)}
    end
  end

  @impl true
  def handle_event("channel_connected", %{"role" => role, "game" => game}, socket) do
    game_assigns = game_to_assigns(game)
    game_assigns = %{game_assigns | board: ensure_board_list(game_assigns.board)}

    {:noreply,
     socket
     |> assign(:role, role)
     |> assign(:game, game_assigns)
     |> assign(:channel_connected, true)}
  end

  @impl true
  def handle_event("game_updated", %{"game" => game}, socket) do
    game_assigns = game_to_assigns(game)
    game_assigns = %{game_assigns | board: ensure_board_list(game_assigns.board)}
    {:noreply, assign(socket, :game, game_assigns)}
  end

  @impl true
  def handle_event("claim_slot", %{"slot" => _slot}, socket) do
    # Slot claiming is handled by JavaScript channel client
    {:noreply, socket}
  end

  defp game_to_assigns(%{__struct__: _} = game) do
    %{
      slug: game.slug,
      board: game.board || List.duplicate("", 9),
      current_player: game.current_player,
      status: game.status,
      winner: game.winner,
      player_x_session: game.player_x_session,
      player_o_session: game.player_o_session
    }
  end

  defp game_to_assigns(game) when is_map(game) do
    %{
      slug: game["slug"] || game[:slug],
      board: (game["board"] || game[:board] || List.duplicate("", 9)) |> ensure_list(),
      current_player: game["current_player"] || game[:current_player],
      status: game["status"] || game[:status] || "waiting",
      winner: game["winner"] || game[:winner],
      player_x_session: game["player_x_session"] || game[:player_x_session],
      player_o_session: game["player_o_session"] || game[:player_o_session]
    }
  end

  defp ensure_list(list) when is_list(list) and length(list) == 9, do: list
  defp ensure_list(list) when is_list(list), do: list ++ List.duplicate("", 9 - length(list))
  defp ensure_list(_), do: List.duplicate("", 9)

  defp ensure_board_list(board) when is_list(board) and length(board) == 9, do: board
  defp ensure_board_list(board) when is_list(board), do: board ++ List.duplicate("", 9 - length(board))
  defp ensure_board_list(_), do: List.duplicate("", 9)

  defp can_move?(role, current_player, status, cell) do
    role in ["X", "O"] and
      status == "playing" and
      role == current_player and
      (cell == nil or cell == "")
  end
end
