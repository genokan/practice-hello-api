defmodule HelloElixir.Metrics do
  @moduledoc false

  use GenServer

  @buckets [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def observe(route, status, duration_seconds) do
    GenServer.cast(__MODULE__, {:observe, route, status, duration_seconds})
  end

  def prometheus, do: GenServer.call(__MODULE__, :prometheus)

  @impl true
  def init(_state), do: {:ok, %{requests: %{}, histograms: %{}}}

  @impl true
  def handle_cast({:observe, route, status, duration_seconds}, state) do
    request_key = {route, status}
    requests = Map.update(state.requests, request_key, 1, &(&1 + 1))

    histogram = Map.get(state.histograms, route, %{count: 0, sum: 0.0, buckets: empty_buckets()})

    histogram = %{
      count: histogram.count + 1,
      sum: histogram.sum + duration_seconds,
      buckets:
        Enum.reduce(@buckets, histogram.buckets, fn bucket, buckets ->
          if duration_seconds <= bucket,
            do: Map.update!(buckets, bucket, &(&1 + 1)),
            else: buckets
        end)
    }

    {:noreply,
     %{state | requests: requests, histograms: Map.put(state.histograms, route, histogram)}}
  end

  @impl true
  def handle_call(:prometheus, _from, state), do: {:reply, format(state), state}

  defp format(state) do
    request_lines =
      state.requests
      |> Enum.sort()
      |> Enum.map_join("", fn {{route, status}, count} ->
        "hello_api_http_requests_total{route=\"#{route}\",status=\"#{status}\"} #{count}\n"
      end)

    histogram_lines =
      state.histograms
      |> Enum.sort()
      |> Enum.map_join("", fn {route, histogram} -> format_histogram(route, histogram) end)

    lab = HelloElixir.Lab.status()
    active = if lab.mode == "idle" or lab.mode == "disabled", do: 0, else: 1
    readiness = if lab.mode == "readiness", do: 1, else: 0
    workers = Map.get(lab, :workers, 0)

    """
    # HELP hello_elixir_up Whether the application is available.
    # TYPE hello_elixir_up gauge
    hello_elixir_up 1
    # HELP hello_elixir_info Immutable application metadata.
    # TYPE hello_elixir_info gauge
    hello_elixir_info{environment=\"#{Application.fetch_env!(:hello_elixir, :app_environment)}\",version=\"#{Application.fetch_env!(:hello_elixir, :app_version)}\"} 1
    # HELP hello_api_http_requests_total Total HTTP requests by route and status.
    # TYPE hello_api_http_requests_total counter
    #{request_lines}# HELP hello_api_http_request_duration_seconds HTTP request duration by route.
    # TYPE hello_api_http_request_duration_seconds histogram
    #{histogram_lines}# HELP hello_api_lab_mode_active Whether a failure-lab mode is active.
    # TYPE hello_api_lab_mode_active gauge
    hello_api_lab_mode_active{mode=\"#{lab.mode}\"} #{active}
    # HELP hello_api_lab_readiness_forced Whether readiness is deliberately failing.
    # TYPE hello_api_lab_readiness_forced gauge
    hello_api_lab_readiness_forced #{readiness}
    # HELP hello_api_lab_workers Number of deliberate CPU or memory fault workers in this pod.
    # TYPE hello_api_lab_workers gauge
    hello_api_lab_workers{mode="#{lab.mode}"} #{workers}
    """
  end

  defp format_histogram(route, histogram) do
    bucket_lines =
      Enum.map_join(@buckets, "", fn bucket ->
        "hello_api_http_request_duration_seconds_bucket{route=\"#{route}\",le=\"#{bucket}\"} #{histogram.buckets[bucket]}\n"
      end)

    """
    #{bucket_lines}hello_api_http_request_duration_seconds_bucket{route=\"#{route}\",le=\"+Inf\"} #{histogram.count}
    hello_api_http_request_duration_seconds_sum{route=\"#{route}\"} #{histogram.sum}
    hello_api_http_request_duration_seconds_count{route=\"#{route}\"} #{histogram.count}
    """
  end

  defp empty_buckets, do: Map.new(@buckets, &{&1, 0})
end
