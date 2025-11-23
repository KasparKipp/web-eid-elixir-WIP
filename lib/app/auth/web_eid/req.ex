defmodule App.Auth.WebEid.Req do
  @moduledoc """
  Web eID authentication backend implemented via Req, talking to a sidecar process.
  """

  @behaviour App.Auth.WebEid.AuthProvider

  @impl App.Auth.WebEid.AuthProvider
  def authenticate(pid, auth_token, nonce) do
    # Spawn async task — non-blocking
    Task.start(fn ->
      payload = get_payload(auth_token, nonce)

      result =
        case Req.post("http://localhost:8080/auth/web-eid", json: payload) do
          {:ok, %{status: 200, body: body}} ->
            {:ok, body}

          {:ok, %{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {:error, reason} ->
            {:error, reason}
        end

      send(pid, {:web_eid_auth_result, result})
    end)

    :ok
  end

  defp get_payload(auth_token, nonce) do
    auth_token
    |> Enum.map(fn {k, v} -> {Macro.underscore(k), v} end)
    |> Enum.into(%{})
    |> Map.put(:nonce, nonce)
  end
end
