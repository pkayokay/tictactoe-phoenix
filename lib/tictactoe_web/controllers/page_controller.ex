defmodule TictactoeWeb.PageController do
  use TictactoeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
