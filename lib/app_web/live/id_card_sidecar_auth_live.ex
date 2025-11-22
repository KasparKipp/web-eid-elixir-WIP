defmodule AppWeb.IdCardSidecarAuthlive do
  use AppWeb, :live_view

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen gap-4 mx-auto max-w-7xl">
      <h2 class="text-3xl">Auth demo with sidecar</h2>
      <button :if={!@auth_token} id="id-auth" phx-hook="WebEidAuth" class="btn">
        Sign in using ID card
      </button>

      <div :if={@auth_token} class="flex flex-col max-w-full">
        <div :if={@json} class="flex flex-col bg-base-200 p-3 rounded-lg">
          <span class="font-semibold text-sm text-base-content">Credentials</span>
          <pre class="text-xs font-mono text-base-content overflow-x-auto">{@json}</pre>
        </div>
        <div class="flex flex-col bg-base-200 p-3 rounded-lg">
          <span class="font-semibold text-sm text-base-content">Nonce</span>
          <pre class="text-xs font-mono text-base-content overflow-x-auto">{@nonce}</pre>
        </div>
        <%= for {key, value} <- @auth_token do %>
          <div class="flex flex-col bg-base-200 p-3 rounded-lg flex-nowrap">
            <span class="font-semibold text-sm text-base-content">{key}</span>
            <pre class="text-xs font-mono text-base-content overflow-x-auto">{value}</pre>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    lv_pid = self()
    {:ok, assign(socket, auth_token: nil, nonce: nil, json: nil, lv_pid: lv_pid)}
  end

  @impl Phoenix.LiveView
  def handle_event("get_nonce", _params, socket) do
    # TODO nonce stored in session and time limited to eg. 3 min
    nonce = App.WebEid.get_nonce()

    socket =
      socket
      |> assign(nonce: nonce)

    {:reply, %{nonce: nonce}, socket}
  end

  # example params
  # "authToken" => %{
  #  "algorithm" => "ES384",
  #  "appVersion" => "https://web-eid.eu/web-eid-app/releases/2.8.0+710",
  #  "format" => "web-eid:1.0",
  #  "signature" => "DI/iS/qGCtBYdzA7ExK8zzKQXkp3Uwft6ZJKwna0EvNKLeSkANSUCJhd1XVoywkjZz3CxkG/nSoprYo9iNpPtKbObdLfPaqjzS2ZDVCxpHbqQ8TPql5ag7kHnF6+H/c6",
  #  "unverifiedCertificate" => "MIID4zCCA0agAwIBAgIQKmoHI1e3eVrfYtBaBzqoiTAKBggqhkjOPQQDBDBYMQswCQYDVQQGEwJFRTEbMBkGA1UECgwSU0sgSUQgU29sdXRpb25zIEFTMRcwFQYDVQRhDA5OVFJFRS0xMDc0NzAxMzETMBEGA1UEAwwKRVNURUlEMjAxODAeFw0yNDAzMDEwNzE0MTlaFw0yOTAyMjgyMTU5NTlaMGsxCzAJBgNVBAYTAkVFMSAwHgYDVQQDDBdLSVBQLEtBU1BBUiwzOTYwNjA5MDgyODENMAsGA1UEBAwES0lQUDEPMA0GA1UEKgwGS0FTUEFSMRowGAYDVQQFExFQTk9FRS0zOTYwNjA5MDgyODB2MBAGByqGSM49AgEGBSuBBAAiA2IABNTFhTlvonUA8j6E2bH41GJCX7Fkz64jos9wvLleiq1nx5Xm200ImljtTgffXqtS1DLtSE5w3JiPx2vw5IRy5IMc2DDfm6uexcC8VPWnmqoIQThfDJXO6n2ujHgYvquk76OCAcAwggG8MAkGA1UdEwQCMAAwHwYDVR0jBBgwFoAU2axw219+vpT4oOS+R6LQNK2aKhIwZgYIKwYBBQUHAQEEWjBYMC0GCCsGAQUFBzAChiFodHRwOi8vYy5zay5lZS9lc3RlaWQyMDE4LmRlci5jcnQwJwYIKwYBBQUHMAGGG2h0dHA6Ly9haWEuc2suZWUvZXN0ZWlkMjAxODAfBgNVHREEGDAWgRQzOTYwNjA5MDgyOEBlZXN0aS5lZTBHBgNVHSAEQDA+MDIGCysGAQQBg5EhAQEBMCMwIQYIKwYBBQUHAgEWFWh0dHBzOi8vd3d3LnNrLmVlL0NQUzAIBgYEAI96AQIwIAYDVR0lAQH/BBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMEMGsGCCsGAQUFBwEDBF8wXTAIBgYEAI5GAQEwUQYGBACORgEFMEcwRRY/aHR0cHM6Ly9zay5lZS9lbi9yZXBvc2l0b3J5L2NvbmRpdGlvbnMtZm9yLXVzZS1vZi1jZXJ0aWZpY2F0ZXMvEwJlbjAdBgNVHQ4EFgQUzlULqANOSfyOJjQB76adr1R14VYwDgYDVR0PAQH/BAQDAgOIMAoGCCqGSM49BAMEA4GKADCBhgJBc1XZVV/yW6g35K/96r9kJ4yPS2m4DJM1veqZfQWvUMmbKf/K5yhVthvSnMlLeD9plfa4ITJzxP4etwOa9LUSA4YCQVzsfnsnBFJj2Xe43MRBZzjEcrl9h/z9GMdk0nS8YSsZIBnWkcpXuYNAzFWaZnW4sRMmwYKNEVQaXvSKQ3k83h4Y"
  # }
  @impl Phoenix.LiveView
  def handle_event("authenticate", %{"authToken" => auth_token}, socket) do
    payload =
      auth_token
      |> Enum.map(fn {k, v} -> {Macro.underscore(k), v} end)
      |> Enum.into(%{})
      |> Map.put(:nonce, socket.assigns.nonce)

    # TODO use Req
    response =
      Req.post!("http://localhost:8080/auth/web-eid", json: payload)

    socket =
      socket
      |> assign(auth_token: auth_token, json: response.body |> JSON.encode!())

    {:reply, %{ok: "message received"}, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(info, socket) do
    IO.inspect(info, label: "Unhandled info")

    {:noreply, socket}
  end
end
