import Config

port = System.get_env("PORT", "4000") |> String.to_integer()

parse_integer = fn variable, default ->
  case Integer.parse(System.get_env(variable, Integer.to_string(default))) do
    {value, ""} -> value
    _ -> default
  end
end

log_level =
  case System.get_env("LOG_LEVEL", "info") |> String.downcase() do
    "debug" -> :debug
    "info" -> :info
    "warning" -> :warning
    "error" -> :error
    "critical" -> :critical
    _ -> :info
  end

config :hello_elixir,
  port: port,
  app_environment: System.get_env("APP_ENV", "development"),
  app_version: System.get_env("APP_VERSION", "dev"),
  database_url: System.get_env("DATABASE_URL"),
  lab_enabled: System.get_env("LAB_ENABLED") == "true",
  lab_max_duration_seconds: parse_integer.("LAB_MAX_DURATION_SECONDS", 300),
  lab_max_latency_milliseconds: parse_integer.("LAB_MAX_LATENCY_MILLISECONDS", 5_000)

config :logger, level: log_level
