defmodule HelloElixir.LabTest do
  use ExUnit.Case, async: false

  setup do
    previous = Application.get_env(:hello_elixir, :lab_enabled)
    Application.put_env(:hello_elixir, :lab_enabled, true)
    HelloElixir.Lab.reset()

    on_exit(fn ->
      if previous == nil,
        do: Application.delete_env(:hello_elixir, :lab_enabled),
        else: Application.put_env(:hello_elixir, :lab_enabled, previous)

      HelloElixir.Lab.reset()
    end)
  end

  test "activates a bounded latency fault and resets it" do
    assert {:ok, %{mode: "latency", value: 25}} =
             HelloElixir.Lab.activate(%{
               "mode" => "latency",
               "duration" => "10",
               "delay_ms" => "25"
             })

    assert :ok = HelloElixir.Lab.before_work()
    assert {:ok, %{mode: "idle"}} = HelloElixir.Lab.reset()
  end

  test "rejects an invalid fault setting" do
    assert {:error, :invalid_value} =
             HelloElixir.Lab.activate(%{
               "mode" => "errors",
               "duration" => "10",
               "error_percent" => "101"
             })
  end
end
