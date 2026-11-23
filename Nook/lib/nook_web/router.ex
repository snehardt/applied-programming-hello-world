defmodule NookWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import NookWeb.UserAuth

  get("/health/live", NookWeb.HealthController, :live)
  get("/health/ready", NookWeb.HealthController, :ready)

  pipeline :browser do
    plug(:accepts, ["html", "json"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {NookWeb.Layouts, :root})
    plug(:protect_from_forgery)

    plug(:put_secure_browser_headers, %{
      "referrer-policy" => "no-referrer",
      "permissions-policy" => "camera=(), microphone=(), geolocation=()",
      "content-security-policy" =>
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'self'; form-action 'self' https://accounts.google.com"
    })

    plug(:fetch_current_scope_for_user)
    plug(NookWeb.BrowserSession)
    plug(NookWeb.LaunchLimits)
    plug(:no_cache)
  end

  defp no_cache(conn, _), do: Plug.Conn.put_resp_header(conn, "cache-control", "no-store")

  scope "/", NookWeb do
    pipe_through(:browser)
    post("/api/boards", PageController, :create)
    get("/api/socket-token", PageController, :socket_token)
    post("/api/room-requests", RoomController, :create)
    get("/api/room-requests/:id", RoomController, :status)
    get("/api/boards/:code/requests", RoomController, :index)
    post("/api/boards/:code/requests/open", RoomController, :open)
    post("/api/boards/:code/requests/:id", RoomController, :decide)
    post("/api/boards/:code/invitations/reuse", PageController, :reusable_invite)
    post("/api/boards/:code/invitations", PageController, :invite)
    delete("/api/boards/:code/invitations", PageController, :disable_invites)
    post("/api/boards/:code/files", AttachmentController, :create)
    get("/api/boards/:code/files/:id", AttachmentController, :show)
    get("/api/boards/:code", PageController, :board)
    get("/invite/:code/:token", InvitationController, :accept)
    get("/recover/:code/:token", InvitationController, :recover)
    get("/save/:code", PageController, :save_prompt)

    live_session :boards, on_mount: [{NookWeb.UserAuth, :mount_current_scope}] do
      live("/", BoardLive, :home)
      live("/b/:code", BoardLive, :board)
    end
  end

  scope "/", NookWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :require_authenticated_user,
      on_mount: [{NookWeb.UserAuth, :require_authenticated}] do
      live("/dashboard", DashboardLive, :index)
      live("/users/settings", UserLive.Settings, :edit)
      live("/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email)
    end

    post("/users/update-password", UserSessionController, :update_password)
  end

  scope "/", NookWeb do
    pipe_through(:browser)

    live_session :current_user, on_mount: [{NookWeb.UserAuth, :mount_current_scope}] do
      live("/users/register", UserLive.Registration, :new)
      live("/users/log-in", UserLive.Login, :new)
      live("/users/log-in/:token", UserLive.Confirmation, :new)
    end

    post("/auth/google", GoogleAuthController, :request)
    get("/auth/google/callback", GoogleAuthController, :callback)
    post("/users/log-in", UserSessionController, :create)
    delete("/users/log-out", UserSessionController, :delete)
  end

  if Application.compile_env(:nook, :dev_routes) do
    scope "/dev" do
      pipe_through(:browser)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
