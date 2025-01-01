import Config

config :logger, :console,
  level: :warning,
  colors: [enabled: false],
  format: "\n$time $metadata[$level] $message\n"
