import Config

if System.get_env("PHX_SERVER") do
  config :vigia, VigiaWeb.Endpoint, server: true
end

config :vigia, VigiaWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() != :test do
  config :vigia,
    alvos_json: System.get_env("VIGIA_ALVOS"),
    senha_hash: System.get_env("VIGIA_SENHA_HASH")

  if url = System.get_env("DATABASE_URL") do
    config :vigia, Vigia.Retrato, {Vigia.Retrato.Postgres, Vigia.Retrato.Postgres.opcoes(url)}
  end

  config :vigia, Vigia.Tailscale,
    oauth_id: System.get_env("TAILSCALE_OAUTH_ID"),
    oauth_segredo: System.get_env("TAILSCALE_OAUTH_SEGREDO"),
    token: System.get_env("TAILSCALE_TOKEN")
end

if config_env() == :dev do
  config :vigia, VigiaWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        ~r"lib/vigia_web/router\.ex$"E,
        ~r"lib/vigia_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE ausente. Gere com: mix phx.gen.secret"

  config :vigia, VigiaWeb.Endpoint,
    server: true,
    url: [host: System.get_env("PHX_HOST", "localhost"), port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base
end
