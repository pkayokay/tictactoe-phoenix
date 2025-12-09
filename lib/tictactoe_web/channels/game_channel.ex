defmodule TictactoeWeb.GameChannel do
  use TictactoeWeb, :channel

  alias Tictactoe.Games

  @impl true
  def join("game:" <> slug, _payload, socket) do
    # Get session ID from socket
    session_id = get_session_id(socket)

    case Games.join_game(slug, session_id) do
      {:ok, game, role} ->
        # Subscribe to game updates
        Phoenix.PubSub.subscribe(Tictactoe.PubSub, "game:#{slug}")

        # Broadcast that someone joined
        broadcast_game_update(slug, game)

        {:ok, %{game: game_to_map(game), role: role}, socket}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_in("move", %{"position" => position}, socket) do
    slug = extract_slug(socket.topic)
    session_id = get_session_id(socket)

    # Get game to check player role
    case Games.get_game(slug) do
      nil ->
        {:reply, {:error, %{reason: "game_not_found"}}, socket}

      game ->
        player = get_player_role(game, session_id)

        if player in ["X", "O"] do
          case Games.make_move(slug, position, player) do
            {:ok, updated_game} ->
              broadcast_game_update(slug, updated_game)
              {:reply, {:ok, %{game: game_to_map(updated_game)}}, socket}

            {:error, reason} ->
              {:reply, {:error, %{reason: reason}}, socket}
          end
        else
          {:reply, {:error, %{reason: "not_a_player"}}, socket}
        end
    end
  end

  @impl true
  def handle_in("claim_slot", %{"slot" => slot}, socket) do
    slug = extract_slug(socket.topic)
    session_id = get_session_id(socket)

    case Games.claim_player_slot(slug, session_id, slot) do
      {:ok, game, role} ->
        broadcast_game_update(slug, game)
        {:reply, {:ok, %{game: game_to_map(game), role: role}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    push(socket, "game_updated", %{game: game_to_map(game)})
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    slug = extract_slug(socket.topic)
    session_id = get_session_id(socket)

    # Release the player slot when they disconnect
    case Games.release_player_slot(slug, session_id) do
      {:ok, game} ->
        broadcast_game_update(slug, game)

      _ ->
        :ok
    end

    :ok
  end

  defp extract_slug("game:" <> slug), do: slug

  defp get_session_id(socket) do
    case socket.assigns do
      %{session_id: session_id} -> session_id
      _ -> nil
    end
  end

  defp get_player_role(game, session_id) do
    cond do
      game.player_x_session == session_id -> "X"
      game.player_o_session == session_id -> "O"
      true -> "spectator"
    end
  end

  defp broadcast_game_update(slug, game) do
    Phoenix.PubSub.broadcast(
      Tictactoe.PubSub,
      "game:#{slug}",
      {:game_updated, game}
    )
  end

  defp game_to_map(game) do
    %{
      slug: game.slug,
      board: game.board,
      current_player: game.current_player,
      status: game.status,
      winner: game.winner,
      player_x_session: game.player_x_session,
      player_o_session: game.player_o_session
    }
  end
end
