import Config

config :nook, :scopes,
  user: [
    default: true,
    module: Nook.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Nook.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :nook, NookWeb.Endpoint,
  render_errors: [formats: [html: NookWeb.ErrorHTML, json: NookWeb.ErrorJSON], layout: false],
  adapter: Bandit.PhoenixAdapter,
  url: [host: System.get_env("NOOK_HOST", "127.0.0.1")],
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "nook-local-development-only-please-set-a-real-secret-before-deployment-12345"
    ),
  pubsub_server: Nook.PubSub,
  check_origin: ["//localhost:4000", "//127.0.0.1:4000"]

config :phoenix, :json_library, Jason
config :nook, ecto_repos: [Nook.Repo]

config :nook, Nook.Repo,
  hostname: System.get_env("PGHOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("PGPORT", "55432")),
  username: System.get_env("PGUSER", "nook"),
  password: System.get_env("NOOK_DATABASE_PASSWORD", ""),
  database: if(config_env() == :test, do: "nook_test", else: "nook_dev"),
  pool_size: 5

nook_db_url =
  if config_env() == :test,
    do: System.get_env("TEST_DATABASE_URL"),
    else: System.get_env("DATABASE_URL")

if nook_db_url, do: config(:nook, Nook.Repo, url: nook_db_url)

config :tailwind,
  version: "4.1.12",
  nook: [
    args: ~w(--input=assets/css/app.css --output=priv/static/assets/tailwind.css),
    cd: Path.expand("..", __DIR__)
  ]

config :nook, NookWeb.Endpoint, live_view: [signing_salt: "nook-live-view"]
config :logger, level: :warning
config :nook, guest_inactivity_days: 7, dev_routes: config_env() == :dev
config :nook, secure_cookies: config_env() == :prod

config :phoenix, :filter_parameters, [
  "password",
  "password_confirmation",
  "code",
  "state",
  "client_secret",
  "id_token",
  "access_token",
  "token",
  "socket_token",
  "_csrf_token"
]

config :nook, Nook.Mailer, adapter: Swoosh.Adapters.Local
config :swoosh, :api_client, false

if config_env() == :test do
  config :nook, expiry_worker: false
  import_config "test.exs"
  config :nook, Nook.Mailer, adapter: Swoosh.Adapters.Test
  config :nook, NookWeb.Endpoint, server: false
  config :nook, Nook.Repo, pool: Ecto.Adapters.SQL.Sandbox
end

if config_env() == :prod, do: import_config("prod.exs")
