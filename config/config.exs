import Config

config :logger, :console,
  level: if(config_env() == :prod, do: :warning, else: :debug),
  colors: [enabled: false],
  format: "\n$time $metadata[$level] $message\n"

import_config "#{config_env()}.exs"
