defmodule HelloElixir.LoadRunner do
  @moduledoc false

  @service_account_path "/var/run/secrets/kubernetes.io/serviceaccount"
  @load_label "practice-lab.opsguy.io/load-run=true"

  def enabled? do
    HelloElixir.Lab.enabled?() and Application.get_env(:hello_elixir, :lab_load_ui_enabled, false)
  end

  def list do
    with true <- enabled?(),
         {:ok, 200, body} <-
           request(
             :get,
             "/apis/batch/v1/namespaces/#{namespace()}/jobs?labelSelector=#{URI.encode_www_form(@load_label)}"
           ),
         {:ok, payload} <- Jason.decode(body) do
      {:ok,
       payload
       |> Map.get("items", [])
       |> Enum.map(&job_summary/1)
       |> Enum.sort_by(& &1.name, :desc)}
    else
      false -> {:error, :disabled}
      {:ok, status, body} -> {:error, "Kubernetes API returned #{status}: #{body}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  def start(profile) when is_binary(profile) do
    with true <- enabled?(),
         true <- profile in profiles(),
         {:ok, 200, body} <- request(:get, cronjob_path(profile)),
         {:ok, cronjob} <- Jason.decode(body),
         job_spec when is_map(job_spec) <- get_in(cronjob, ["spec", "jobTemplate", "spec"]),
         job = new_job(profile, job_spec),
         {:ok, 201, _body} <-
           request(:post, "/apis/batch/v1/namespaces/#{namespace()}/jobs", Jason.encode!(job)) do
      :ok
    else
      false -> {:error, :invalid_profile}
      nil -> {:error, :invalid_cronjob}
      {:ok, status, body} -> {:error, "Kubernetes API returned #{status}: #{body}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp profiles, do: ["smoke", "standard", "spike", "stress", "sustained", "soak"]

  defp new_job(profile, job_spec) do
    %{
      "apiVersion" => "batch/v1",
      "kind" => "Job",
      "metadata" => %{
        "generateName" => "#{cronjob_name(profile)}-",
        "labels" => %{
          "app.kubernetes.io/component" => "load-generator",
          "practice-lab.opsguy.io/load-profile" => profile,
          "practice-lab.opsguy.io/load-run" => "true"
        }
      },
      "spec" => job_spec
    }
  end

  defp job_summary(job) do
    metadata = Map.get(job, "metadata", %{})
    status = Map.get(job, "status", %{})

    %{
      name: Map.get(metadata, "name", "unknown"),
      profile: get_in(metadata, ["labels", "practice-lab.opsguy.io/load-profile"]) || "unknown",
      active: Map.get(status, "active", 0),
      succeeded: Map.get(status, "succeeded", 0),
      failed: Map.get(status, "failed", 0),
      started_at: Map.get(status, "startTime"),
      completed_at: Map.get(status, "completionTime")
    }
  end

  defp cronjob_path(profile),
    do: "/apis/batch/v1/namespaces/#{namespace()}/cronjobs/#{cronjob_name(profile)}"

  defp cronjob_name(profile),
    do: "#{Application.fetch_env!(:hello_elixir, :lab_load_name_prefix)}-#{profile}"

  defp namespace, do: System.get_env("POD_NAMESPACE", "default")

  defp request(method, path, body \\ nil) do
    :inets.start()
    :ssl.start()

    token = token_path() |> File.read!() |> String.trim() |> String.to_charlist()
    headers = [{~c"authorization", 'Bearer ' ++ token}, {~c"content-type", ~c"application/json"}]
    url = 'https://kubernetes.default.svc' ++ String.to_charlist(path)
    request = if body, do: {url, headers, ~c"application/json", body}, else: {url, headers}

    options = [
      ssl: [
        verify: :verify_peer,
        cacertfile: String.to_charlist(Path.join(@service_account_path, "ca.crt")),
        server_name_indication: ~c"kubernetes.default.svc"
      ]
    ]

    case :httpc.request(method, request, options, []) do
      {:ok, {{_http, status, _reason}, _headers, response}} -> {:ok, status, to_string(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp token_path, do: Path.join(@service_account_path, "token")
end
