defmodule HelloElixirWeb.MetricsController do
  use Phoenix.Controller, formats: [:text]

  def show(conn, _params) do
    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, HelloElixir.Metrics.prometheus())
  end
end
