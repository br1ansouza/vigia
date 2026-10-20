defmodule VigiaWeb.Router do
  use VigiaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VigiaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  get "/saude", VigiaWeb.SaudeController, :show

  scope "/", VigiaWeb do
    pipe_through :browser

    get "/", PageController, :home
  end
end
