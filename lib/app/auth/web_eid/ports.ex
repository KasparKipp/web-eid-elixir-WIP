defmodule App.Auth.WebEid.Ports do
  @moduledoc """
  Web eID authentication backend implemented via Ports, talking to a sidecar process.
  """

  @behaviour App.Auth.WebEid.AuthProvider

  @impl App.Auth.WebEid.AuthProvider
  def authenticate(lv_pid, auth_token, nonce) do
    Task.start_link(fn ->
      port =
        Port.open(
          {:spawn, "jauth certsPath=certs/prod localOrigin=https://localhost:4001"},
          [:binary]
        )

      payload =
        %{"authToken" => auth_token, "nonce" => nonce}
        |> JSON.encode!()

      dbg(payload)

      Port.command(port, payload <> "\n")

      receive do
        {^port, {:data, data}} ->
          send(lv_pid, {:web_eid_auth_result, {:ok, data}})
      after
        1000 ->
          send(lv_pid, {:web_eid_auth_result, {:error, :timeout}})
      end
    end)

    :ok
  end
end
