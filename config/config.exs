import Config

config :logger, :console,
  level: if(config_env() == :prod, do: :warning, else: :debug),
  colors: [enabled: config_env() == :dev],
  format: "\n$time $metadata[$level] $message\n"
