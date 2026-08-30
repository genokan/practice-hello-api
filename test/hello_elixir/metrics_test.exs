defmodule HelloElixir.MetricsTest do
  use ExUnit.Case, async: false

  test "emits request counters and cumulative duration buckets" do
    HelloElixir.Metrics.observe("/work", 200, 0.02)
    output = HelloElixir.Metrics.prometheus()

    assert output =~ "hello_api_http_requests_total{route=\"/work\",status=\"200\"} 1"
    assert output =~ "hello_api_http_request_duration_seconds_bucket{route=\"/work\",le=\"0.025\"} 1"
    assert output =~ "hello_api_http_request_duration_seconds_bucket{route=\"/work\",le=\"0.01\"} 0"
  end
end
