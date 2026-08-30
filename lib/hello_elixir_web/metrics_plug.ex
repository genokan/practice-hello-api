defmodule HelloElixirWeb.MetricsPlug do
  @moduledoc false

  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    started_at = System.monotonic_time()

    register_before_send(conn, fn conn ->
      duration_seconds =
        System.convert_time_unit(System.monotonic_time() - started_at, :native, :nanosecond) /
          1_000_000_000

      HelloElixir.Metrics.observe(conn.request_path, conn.status || 200, duration_seconds)
      conn
    end)
  end
end
