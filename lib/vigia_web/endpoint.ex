defmodule VigiaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :vigia

  @session_options [
    store: :cookie,
    key: "_vigia_key",
    signing_salt: "OO9q/1T9",
    encryption_salt: "vigia-sessao",
    same_site: "Lax",
    http_only: true,
    secure: Application.compile_env(:vigia, :cookie_seguro, false),
    max_age: 30 * 24 * 60 * 60
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :vigia,
    gzip: not code_reloading?,
    only: VigiaWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug VigiaWeb.Router
end
