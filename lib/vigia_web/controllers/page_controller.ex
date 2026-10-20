defmodule VigiaWeb.PageController do
  use VigiaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
