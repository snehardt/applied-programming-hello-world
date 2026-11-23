defmodule NookWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :nook

  @session_options [
    store: :cookie,
    key: "_nook_key",
    signing_salt: "nook-session",
    encryption_salt: "nook-session-encryption-v1",
    max_age: 31_536_000,
    secure: Application.compile_env(:nook, :secure_cookies, false),
    same_site: "Lax"
  ]
  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  socket("/socket", NookWeb.UserSocket,
    websocket: [max_frame_size: 12_500_000, connect_info: [session: @session_options]],
    longpoll: false
  )

  plug(Plug.Static, at: "/", from: {:nook, "priv/static"}, only: ~w(assets))
  plug(Plug.RequestId)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    json_decoder: Jason,
    length: 12_000_000
  )

  plug(Plug.MethodOverride)
  plug(Plug.Session, @session_options)
  plug(NookWeb.Router)
end
