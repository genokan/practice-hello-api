defmodule HelloElixirWeb.LabController do
  use Phoenix.Controller, formats: [:html, :json]

  def show(conn, params) do
    if HelloElixir.Lab.enabled?() do
      status = HelloElixir.Lab.status()
      send_html(conn, :ok, page(status, load_jobs(), nil, started_message(params)))
    else
      send_resp(conn, :not_found, "not found")
    end
  end

  def status(conn, _params) do
    if HelloElixir.Lab.enabled?(),
      do: json(conn, HelloElixir.Lab.status()),
      else: send_resp(conn, :not_found, "not found")
  end

  def load_status(conn, _params) do
    case HelloElixir.LoadRunner.list() do
      {:ok, jobs} -> json(conn, %{jobs: jobs})
      {:error, :disabled} -> send_resp(conn, :not_found, "not found")
      {:error, reason} -> json(conn |> put_status(:bad_gateway), %{error: reason})
    end
  end

  def activate(conn, params) do
    case HelloElixir.Lab.activate(params) do
      {:ok, _status} ->
        redirect(conn, to: "/lab")

      {:error, _reason} ->
        send_html(
          conn,
          :unprocessable_entity,
          page(HelloElixir.Lab.status(), load_jobs(), "Invalid or out-of-range lab settings.")
        )
    end
  end

  def reset(conn, _params) do
    HelloElixir.Lab.reset()
    redirect(conn, to: "/lab")
  end

  def start_load(conn, %{"profile" => profile}) do
    case HelloElixir.LoadRunner.start(profile) do
      :ok ->
        redirect(conn, to: "/lab?started=#{URI.encode_www_form(profile)}")

      {:error, _reason} ->
        send_html(
          conn,
          :unprocessable_entity,
          page(HelloElixir.Lab.status(), load_jobs(), "Could not start that load profile.")
        )
    end
  end

  defp page(status, load, error \\ nil, notice \\ nil) do
    error_html = if error, do: "<p class=\"error\">#{error}</p>", else: ""
    notice_html = if notice, do: "<p class=\"notice\">#{escape(notice)}</p>", else: ""

    refresh_html =
      if load_active?(load), do: "<meta http-equiv=\"refresh\" content=\"5\">", else: ""

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        #{refresh_html}
        <title>hello-api failure lab</title>
        <style>
          body { background: #101418; color: #e5edf4; font: 16px system-ui, sans-serif; margin: 2rem auto; max-width: 54rem; padding: 0 1rem; }
          h1, h2, h3 { color: #91d5ff; } form { background: #19232d; border-radius: .5rem; margin: 1rem 0; padding: 1rem; }
          label { display: block; margin: .6rem 0; } input, select, button { font: inherit; padding: .4rem; } button { cursor: pointer; }
          code { color: #f9d877; } .error { background: #641f1f; padding: .8rem; } .notice { background: #194d32; padding: .8rem; } .warning { color: #ffd580; }
          .load-section { margin: 1.5rem 0; } .load-section > p { color: #b8c7d4; }
          .run-grid { display: grid; gap: .75rem; grid-template-columns: repeat(auto-fit, minmax(17rem, 1fr)); }
          .run-card { background: #19232d; border: 1px solid #385064; border-radius: .6rem; padding: 1rem; }
          .run-card__head { align-items: center; display: flex; gap: .75rem; justify-content: space-between; }
          .run-card__head strong { font-size: 1.1rem; } .badge { border-radius: 999px; font-size: .8rem; font-weight: 700; padding: .25rem .55rem; }
          .badge-running { background: #1c6b45; color: #d6ffe6; } .badge-pending { background: #76591b; color: #fff2bd; }
          .badge-passed { background: #315c78; color: #d6efff; } .badge-failed { background: #7d2929; color: #ffe0e0; }
          .run-card dl { display: grid; gap: .4rem .75rem; grid-template-columns: max-content 1fr; margin: .9rem 0 0; }
          .run-card dt { color: #9fb4c6; } .run-card dd { margin: 0; overflow-wrap: anywhere; }
          .run-history { overflow-x: auto; } table { border-collapse: collapse; min-width: 40rem; width: 100%; }
          th, td { border-bottom: 1px solid #385064; padding: .7rem; text-align: left; vertical-align: top; } th { color: #9fb4c6; font-size: .8rem; letter-spacing: .03em; text-transform: uppercase; }
          @media (max-width: 38rem) { body { margin: 1rem auto; } .run-card dl { grid-template-columns: 1fr; gap: .1rem; } .run-card dd { margin-bottom: .5rem; } }
        </style>
      </head>
      <body>
        <h1>hello-api failure lab</h1>
        <p class="warning">Staging-only. Faults are pod-local and automatically reset after the selected duration.</p>
        #{error_html}
        #{notice_html}
        <p>Pod: <code>#{escape(status.pod)}</code><br>Active mode: <code>#{status.mode}</code><br>Fault workers: <code>#{status.workers}</code><br>Expires: <code>#{status.expires_at || "not active"}</code></p>
        <form method="post" action="/lab/fault">
          <h2>Activate a fault</h2>
          <label>Mode
            <select name="mode">
              <option value="latency">Inject latency into /work</option>
              <option value="errors">Inject 503 responses from /work</option>
              <option value="readiness">Fail readiness</option>
              <option value="cpu">Burn CPU in this pod</option>
              <option value="memory">Allocate memory in this pod</option>
            </select>
          </label>
          <label>Duration in seconds <input type="number" name="duration" min="1" max="300" value="60" required></label>
          <label>Latency in milliseconds (latency mode) <input type="number" name="delay_ms" min="0" max="5000" value="500"></label>
          <label>Error percentage (error mode) <input type="number" name="error_percent" min="0" max="100" value="25"></label>
          <label>CPU workers (CPU mode) <input type="number" name="cpu_workers" min="1" max="8" value="2"></label>
          <label>Memory MiB (memory mode) <input type="number" name="memory_mib" min="1" max="512" value="128"></label>
          <button type="submit">Activate</button>
        </form>
        <form method="post" action="/lab/reset"><button type="submit">Reset this pod</button></form>
        #{load_html(load)}
        <p><a href="/lab/status">Fault JSON</a> · <a href="/lab/load">Load JSON</a></p>
      </body>
    </html>
    """
  end

  defp load_jobs do
    case HelloElixir.LoadRunner.list() do
      {:ok, jobs} -> {:enabled, jobs}
      {:error, :disabled} -> :disabled
      {:error, _reason} -> :unavailable
    end
  end

  defp load_html({:enabled, jobs}) do
    active_jobs = Enum.filter(jobs, &(&1.active > 0))
    completed_jobs = Enum.reject(jobs, &(&1.active > 0))

    activity = active_load_html(active_jobs)

    history =
      case completed_jobs do
        [] ->
          "<p>No completed runs yet.</p>"

        _ ->
          "<div class=\"run-history\"><table><thead><tr><th>Profile</th><th>Job</th><th>Status</th><th>Started</th><th>Completed</th></tr></thead><tbody>#{load_history_rows(completed_jobs)}</tbody></table></div>"
      end

    """
    <form method="post" action="/lab/load">
      <h2>Run k6 load</h2>
      <p>Creates one staging Job from the chart-declared profile. Runs are independent, so a standard load can stay active while you start a spike or stress run.</p>
      <label>Profile
        <select name="profile">
          <option value="smoke">Smoke — light verification</option>
          <option value="standard">Standard — 10 virtual users for 30 minutes</option>
          <option value="spike">Spike — short high concurrency</option>
          <option value="stress">Stress — maximum sustained concurrency</option>
          <option value="sustained">Sustained — steady pressure</option>
        </select>
      </label>
      <button type="submit">Start k6 run</button>
    </form>
    <h2>Load runs</h2>
    #{activity}
    <section class="load-section">
      <h3>Recent completed runs</h3>
      #{history}
    </section>
    """
  end

  defp load_html(:disabled),
    do: "<p class=\"warning\">k6 controls are disabled for this environment.</p>"

  defp load_html(:unavailable), do: "<p class=\"error\">k6 status is temporarily unavailable.</p>"

  defp load_active?({:enabled, jobs}), do: Enum.any?(jobs, &(&1.active > 0))
  defp load_active?(_load), do: false

  defp active_load_html([]), do: ""

  defp active_load_html(jobs) do
    cards = Enum.map_join(jobs, "", &load_job_card/1)
    count_label = if length(jobs) == 1, do: "1 run", else: "#{length(jobs)} runs"

    """
    <section class="load-section">
      <h3>Active load runs</h3>
      <p class="notice">#{count_label} active. This page refreshes every 5 seconds.</p>
      <div class="run-grid">#{cards}</div>
    </section>
    """
  end

  defp load_job_card(job) do
    {label, class} = job_state(job)

    """
    <article class="run-card">
      <div class="run-card__head"><strong>#{escape(job.profile)}</strong><span class="badge badge-#{class}">#{label}</span></div>
      <dl>
        <dt>Job</dt><dd><code>#{escape(job.name)}</code></dd>
        <dt>Started</dt><dd>#{escape(job.started_at || "pending")}</dd>
      </dl>
    </article>
    """
  end

  defp load_history_rows(jobs) do
    Enum.map_join(jobs, "", fn job ->
      {label, class} = job_state(job)

      "<tr><td>#{escape(job.profile)}</td><td><code>#{escape(job.name)}</code></td><td><span class=\"badge badge-#{class}\">#{label}</span></td><td>#{escape(job.started_at || "pending")}</td><td>#{escape(job.completed_at || "—")}</td></tr>"
    end)
  end

  defp job_state(job) do
    cond do
      job.active > 0 -> {"Running", "running"}
      job.succeeded > 0 -> {"Passed", "passed"}
      job.failed > 0 -> {"Failed", "failed"}
      true -> {"Pending", "pending"}
    end
  end

  defp started_message(%{"started" => profile}),
    do: "Started #{profile}; waiting for the Job to run."

  defp started_message(_params), do: nil

  defp send_html(conn, status, body) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp escape(value), do: value |> to_string() |> Plug.HTML.html_escape() |> IO.iodata_to_binary()
end
