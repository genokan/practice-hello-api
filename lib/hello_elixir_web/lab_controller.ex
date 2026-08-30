defmodule HelloElixirWeb.LabController do
  use Phoenix.Controller, formats: [:html, :json]

  def show(conn, _params) do
    if HelloElixir.Lab.enabled?() do
      status = HelloElixir.Lab.status()
      send_html(conn, :ok, page(status))
    else
      send_resp(conn, :not_found, "not found")
    end
  end

  def status(conn, _params) do
    if HelloElixir.Lab.enabled?(),
      do: json(conn, HelloElixir.Lab.status()),
      else: send_resp(conn, :not_found, "not found")
  end

  def activate(conn, params) do
    case HelloElixir.Lab.activate(params) do
      {:ok, _status} ->
        redirect(conn, to: "/lab")

      {:error, _reason} ->
        send_html(
          conn,
          :unprocessable_entity,
          page(HelloElixir.Lab.status(), "Invalid or out-of-range lab settings.")
        )
    end
  end

  def reset(conn, _params) do
    HelloElixir.Lab.reset()
    redirect(conn, to: "/lab")
  end

  defp page(status, error \\ nil) do
    error_html = if error, do: "<p class=\"error\">#{error}</p>", else: ""

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>hello-api failure lab</title>
        <style>
          body { background: #101418; color: #e5edf4; font: 16px system-ui, sans-serif; margin: 2rem auto; max-width: 54rem; padding: 0 1rem; }
          h1, h2 { color: #91d5ff; } form { background: #19232d; border-radius: .5rem; margin: 1rem 0; padding: 1rem; }
          label { display: block; margin: .6rem 0; } input, select, button { font: inherit; padding: .4rem; } button { cursor: pointer; }
          code { color: #f9d877; } .error { background: #641f1f; padding: .8rem; } .warning { color: #ffd580; }
        </style>
      </head>
      <body>
        <h1>hello-api failure lab</h1>
        <p class="warning">Staging-only, pod-local, and automatically reset after the selected duration.</p>
        #{error_html}
        <p>Pod: <code>#{escape(status.pod)}</code><br>Active mode: <code>#{status.mode}</code><br>Expires: <code>#{status.expires_at || "not active"}</code></p>
        <form method="post" action="/lab/fault">
          <h2>Activate a fault</h2>
          <label>Mode
            <select name="mode">
              <option value="latency">Inject latency into /work</option>
              <option value="errors">Inject 503 responses from /work</option>
              <option value="readiness">Fail readiness</option>
            </select>
          </label>
          <label>Duration in seconds <input type="number" name="duration" min="1" max="300" value="60" required></label>
          <label>Latency in milliseconds (latency mode) <input type="number" name="delay_ms" min="0" max="5000" value="500"></label>
          <label>Error percentage (error mode) <input type="number" name="error_percent" min="0" max="100" value="25"></label>
          <button type="submit">Activate</button>
        </form>
        <form method="post" action="/lab/reset"><button type="submit">Reset this pod</button></form>
        <p>Generate load against <code>/work</code>; <a href="/lab/status">JSON status</a>.</p>
      </body>
    </html>
    """
  end

  defp send_html(conn, status, body) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp escape(value), do: value |> to_string() |> Plug.HTML.html_escape() |> IO.iodata_to_binary()
end
