defmodule HelloElixirWeb.StatusController do
  use Phoenix.Controller, formats: [:json]

  def show(conn, _params) do
    json(conn, %{
      delivery: "gitops",
      environment: Application.fetch_env!(:hello_elixir, :app_environment),
      status: "ok",
      version: Application.fetch_env!(:hello_elixir, :app_version)
    })
  end

  def work(conn, _params) do
    case HelloElixir.Lab.before_work() do
      :ok ->
        json(conn, %{pod: System.get_env("HOSTNAME", "local"), status: "ok"})

      {:error, status} ->
        conn |> put_status(status) |> json(%{status: "injected_failure"})
    end
  end
end
