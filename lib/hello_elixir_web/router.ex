defmodule HelloElixirWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(HelloElixirWeb.MetricsPlug)
  end

  pipeline :browser do
    plug(:accepts, ["html"])

    plug(Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Phoenix.json_library()
    )

    plug(HelloElixirWeb.MetricsPlug)
  end

  scope "/" do
    pipe_through(:api)

    get("/", HelloElixirWeb.StatusController, :show)
    get("/work", HelloElixirWeb.StatusController, :work)
    get("/health/live", HelloElixirWeb.HealthController, :live)
    get("/health/ready", HelloElixirWeb.HealthController, :ready)
    get("/metrics", HelloElixirWeb.MetricsController, :show)
    get("/lab/status", HelloElixirWeb.LabController, :status)
    get("/lab/load", HelloElixirWeb.LabController, :load_status)
  end

  scope "/lab" do
    pipe_through(:browser)

    get("/", HelloElixirWeb.LabController, :show)
    post("/fault", HelloElixirWeb.LabController, :activate)
    post("/reset", HelloElixirWeb.LabController, :reset)
    post("/load", HelloElixirWeb.LabController, :start_load)
  end
end
