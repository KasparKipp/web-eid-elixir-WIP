defmodule AppWeb.PageLive do
  use AppWeb, :live_view

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <h2>PageLive</h2>
    </div>
    """
  end
end
