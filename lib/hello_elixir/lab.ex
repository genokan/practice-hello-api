defmodule HelloElixir.Lab do
  @moduledoc false

  use GenServer

  require Logger

  @default_duration_seconds 60

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def enabled?, do: Application.get_env(:hello_elixir, :lab_enabled, false)

  def status do
    if enabled?(), do: GenServer.call(__MODULE__, :status), else: disabled_status()
  end

  def ready? do
    not enabled?() or GenServer.call(__MODULE__, :ready?)
  end

  def before_work do
    if enabled?(), do: GenServer.call(__MODULE__, :before_work), else: :ok
  end

  def activate(params) do
    if enabled?(), do: GenServer.call(__MODULE__, {:activate, params}), else: {:error, :disabled}
  end

  def reset do
    if enabled?(), do: GenServer.call(__MODULE__, :reset), else: {:error, :disabled}
  end

  @impl true
  def init(_state), do: {:ok, idle_state()}

  @impl true
  def handle_call(:status, _from, state), do: {:reply, public_status(state), state}

  def handle_call(:ready?, _from, state), do: {:reply, state.mode != :readiness, state}

  def handle_call(:before_work, _from, %{mode: :latency, value: delay_ms} = state) do
    Process.sleep(delay_ms)
    {:reply, :ok, state}
  end

  def handle_call(:before_work, _from, %{mode: :errors, value: percentage} = state) do
    reply = if :rand.uniform(100) <= percentage, do: {:error, 503}, else: :ok
    {:reply, reply, state}
  end

  def handle_call(:before_work, _from, state), do: {:reply, :ok, state}

  def handle_call(:reset, _from, state) do
    state = reset_state(state)
    Logger.info("failure lab reset")
    {:reply, {:ok, public_status(state)}, state}
  end

  def handle_call({:activate, params}, _from, state) do
    with {:ok, mode} <- parse_mode(params["mode"]),
         {:ok, duration_seconds} <- parse_duration(params["duration"]),
         {:ok, value} <- parse_value(mode, params) do
      state =
        state
        |> reset_state()
        |> Map.merge(%{
          mode: mode,
          value: value,
          expires_at: System.system_time(:second) + duration_seconds,
          token: make_ref()
        })
        |> start_fault_workers()

      Process.send_after(self(), {:expire, state.token}, duration_seconds * 1_000)

      Logger.warning("failure lab activated",
        mode: mode,
        duration_seconds: duration_seconds,
        value: value
      )

      {:reply, {:ok, public_status(state)}, state}
    else
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:expire, token}, %{token: token} = state) do
    state = reset_state(state)
    Logger.info("failure lab expired")
    {:noreply, state}
  end

  def handle_info({:expire, _token}, state), do: {:noreply, state}

  defp idle_state do
    %{mode: :idle, value: 0, expires_at: nil, token: nil, workers: []}
  end

  defp reset_state(state) do
    Enum.each(Map.get(state, :workers, []), fn pid ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    idle_state()
  end

  defp disabled_status do
    %{enabled: false, mode: "disabled", expires_at: nil, value: 0, pod: pod_name()}
  end

  defp public_status(state) do
    %{
      enabled: true,
      mode: Atom.to_string(state.mode),
      expires_at: state.expires_at,
      value: state.value,
      workers: length(state.workers),
      pod: pod_name()
    }
  end

  defp parse_mode("latency"), do: {:ok, :latency}
  defp parse_mode("errors"), do: {:ok, :errors}
  defp parse_mode("readiness"), do: {:ok, :readiness}
  defp parse_mode("cpu"), do: {:ok, :cpu}
  defp parse_mode("memory"), do: {:ok, :memory}
  defp parse_mode(_mode), do: {:error, :invalid_mode}

  defp parse_duration(value) do
    case Integer.parse(value || "") do
      {duration, ""} when duration > 0 ->
        if duration <= max_duration_seconds(),
          do: {:ok, duration},
          else: {:error, :invalid_duration}

      _ ->
        {:error, :invalid_duration}
    end
  end

  defp parse_value(:latency, params) do
    parse_bounded_integer(params["delay_ms"], max_latency_milliseconds())
  end

  defp parse_value(:errors, params) do
    parse_bounded_integer(params["error_percent"], 100)
  end

  defp parse_value(:readiness, _params), do: {:ok, 1}
  defp parse_value(:cpu, params),
    do: parse_bounded_integer(params["cpu_workers"], max_cpu_workers())

  defp parse_value(:memory, params),
    do: parse_bounded_integer(params["memory_mib"], max_memory_mib())

  defp parse_bounded_integer(value, maximum) do
    case Integer.parse(value || "") do
      {integer, ""} when integer >= 0 and integer <= maximum -> {:ok, integer}
      _ -> {:error, :invalid_value}
    end
  end

  defp max_duration_seconds,
    do: Application.get_env(:hello_elixir, :lab_max_duration_seconds, @default_duration_seconds)

  defp max_latency_milliseconds,
    do: Application.get_env(:hello_elixir, :lab_max_latency_milliseconds, 5_000)

  defp max_cpu_workers,
    do: Application.get_env(:hello_elixir, :lab_max_cpu_workers, 8)

  defp max_memory_mib,
    do: Application.get_env(:hello_elixir, :lab_max_memory_mib, 512)

  defp start_fault_workers(%{mode: :cpu, value: count} = state) do
    workers =
      for _ <- 1..count do
        Task.Supervisor.async_nolink(HelloElixir.Lab.TaskSupervisor, fn ->
          burn_cpu(<<0::8192>>)
        end).pid
      end

    %{state | workers: workers}
  end

  defp start_fault_workers(%{mode: :memory, value: mib} = state) do
    worker =
      Task.Supervisor.async_nolink(HelloElixir.Lab.TaskSupervisor, fn ->
        hold_memory(:binary.copy(<<0>>, mib * 1_048_576))
      end).pid

    %{state | workers: [worker]}
  end

  defp start_fault_workers(state), do: state

  defp burn_cpu(data) do
    burn_cpu(:crypto.hash(:sha256, data))
  end

  defp hold_memory(data) do
    receive do
      :stop -> :ok
    after
      :infinity -> byte_size(data)
    end
  end

  defp pod_name, do: System.get_env("HOSTNAME", "local")
end
