defmodule TictactoeWeb.GameLive.Index do
  use TictactoeWeb, :live_view

  alias Tictactoe.Games

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:slug, nil)
     |> assign(:form, to_form(%{}, as: :game))}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    case Games.create_game() do
      {:ok, game} ->
        {:noreply, push_navigate(socket, to: ~p"/game/#{game.slug}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create game. Please try again.")}
    end
  end

  @impl true
  def handle_event("join_game", %{"game" => %{"slug" => slug}}, socket) do
    case Games.get_game(slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Game not found. Please check the slug.")}

      _game ->
        {:noreply, push_navigate(socket, to: ~p"/game/#{slug}")}
    end
  end

  @impl true
  def handle_event("validate", %{"game" => %{"slug" => slug}}, socket) do
    {:noreply, assign(socket, :slug, slug)}
  end
end
