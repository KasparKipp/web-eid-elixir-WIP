defmodule AppWeb.PageLive do
  use AppWeb, :live_view

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <h2>PageLive</h2>
      <span id="1" data-timestamp={DateTime.utc_now()} phx-hook="TimeAgo"></span>
    </div>
    """
  end
end
