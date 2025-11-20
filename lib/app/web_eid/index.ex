defmodule App.WebEid do
  @nonce_bytes 32

  def get_nonce() do
    :crypto.strong_rand_bytes(@nonce_bytes) |> Base.encode64()
  end
end
