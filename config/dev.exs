import Config

config :vigia, VigiaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "jivBVgh3RnANFwojWApaSLYUawVU4Q9MX7bjPlVLeNJgwhTX7y0Ej98jFbOUAqwF",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:vigia, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:vigia, ~w(--watch)]}
  ]

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
