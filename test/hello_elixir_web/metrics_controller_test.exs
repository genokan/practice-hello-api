defmodule HelloElixirWeb.MetricsControllerTest do
  use ExUnit.Case, async: true

  test "is a Phoenix controller plug" do
    assert function_exported?(HelloElixirWeb.MetricsController, :init, 1)
    assert function_exported?(HelloElixirWeb.MetricsController, :call, 2)
  end
end
