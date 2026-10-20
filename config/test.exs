import Config

config :vigia,
  demo: false,
  req_sonda: [plug: {Req.Test, Vigia.Sonda.Http}],
  req_tailscale: [plug: {Req.Test, Vigia.Tailscale}],
  req_push: [plug: {Req.Test, Vigia.Push}]

config :vigia, VigiaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "4hpB3H1gSBz8YsXTdT/m4+7LsLikE1j2mRziw1MXJ6S2CsOmxBAnStbakjTikdXE",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :phoenix,
  sort_verified_routes_query_params: true
