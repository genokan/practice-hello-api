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
end
