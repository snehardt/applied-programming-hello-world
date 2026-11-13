defmodule NookWeb do
  def static_paths, do: ~w(assets)

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: NookWeb.Endpoint,
        router: NookWeb.Router,
        statics: NookWeb.static_paths()
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: false
      import NookWeb.CoreComponents
      alias NookWeb.Layouts
      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]
      import Plug.Conn
      unquote(verified_routes())
    end
  end

  defmacro __using__(which), do: apply(__MODULE__, which, [])
end
