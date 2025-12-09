defmodule TictactoeWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "game:*", TictactoeWeb.GameChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # Generate a unique session ID for this connection
    session_id = generate_session_id()
    socket = assign(socket, :session_id, session_id)
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64(padding: false)
    |> String.slice(0, 22)
  end
end
