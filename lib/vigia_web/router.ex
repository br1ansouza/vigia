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

    get "/entrar", SessaoController, :new
    post "/entrar", SessaoController, :create
    delete "/sair", SessaoController, :delete

    live_session :painel, on_mount: {VigiaWeb.Acesso, :padrao} do
      live "/", PainelLive
    end
  end
end
