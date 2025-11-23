defmodule App.Auth.WebEid.AuthProvider do
  @moduledoc """
    A behaviour for Web eID authentication for different backends.
  """
  @providers %{
    sidecar: App.Auth.WebEid.Req,
    ports: App.Auth.WebEid.Ports,
    jinterface: App.Auth.WebEid.Jinterface
  }
  @doc """
    Dispatch authentication to the correct backend.
  """
  @spec authenticate(:sidecar | :ports | :jinterface, pid(), auth_token(), binary()) ::
          :ok | {:error, term()}
  def authenticate(which, pid, auth_token, nonce) do
    impl = Map.fetch!(@providers, which)
    impl.authenticate(pid, auth_token, nonce)
  end

  @typedoc """
    Web eID auth token passed to authentication backends.
    All fields are binaries (Elixir strings).
  """
  @type auth_token :: %{
          unverified_certificate: binary,
          format: binary,
          signature: binary,
          algorithm: binary
        }
  @doc false
  @callback authenticate(
              pid :: pid(),
              auth_toke :: %{
                unverified_certificate: binary,
                format: binary,
                signature: binary,
                algorithm: binary
              },
              nonce: binary
            ) :: :ok | {:error, term()}
end
