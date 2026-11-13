import Config

auth_mode = System.get_env("NOOK_AUTH_MODE", "email")
if auth_mode not in ["email", "google"], do: raise("NOOK_AUTH_MODE must be email or google")
config :nook, :email_auth_enabled, auth_mode == "email"
client_id = System.get_env("GOOGLE_CLIENT_ID")
client_secret = System.get_env("GOOGLE_CLIENT_SECRET")
google_host = System.get_env("NOOK_HOST") || System.get_env("RENDER_EXTERNAL_HOSTNAME")

redirect_uri =
  System.get_env("GOOGLE_REDIRECT_URI") ||
    if(google_host,
      do: "https://#{google_host}/auth/google/callback",
      else: "http://127.0.0.1:4000/auth/google/callback"
    )

if is_binary(client_id) and byte_size(client_id) > 0 and is_binary(client_secret) and
     byte_size(client_secret) > 0 do
  uri = URI.parse(redirect_uri)

  valid =
    uri.scheme == "https" ||
      (config_env() != :prod && uri.scheme == "http" && uri.host in ["127.0.0.1", "localhost"])

  if !valid || !is_binary(uri.host) || (config_env() == :prod && uri.host != google_host) ||
       uri.path != "/auth/google/callback" || uri.query || uri.fragment || uri.userinfo,
     do: raise("Invalid Google callback URL")

  config :nook, :google_oauth,
    client_id: client_id,
    client_secret: client_secret,
    redirect_uri: redirect_uri
else
  if auth_mode == "google",
    do: raise("Google sign-in requires GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET")
end

if config_env() == :prod do
  required = fn key ->
    case System.get_env(key) do
      value when is_binary(value) and byte_size(value) > 0 -> value
      _ -> raise "Missing required production setting: #{key}"
    end
  end

  secret = required.("SECRET_KEY_BASE")
  if byte_size(secret) < 64, do: raise("SECRET_KEY_BASE must have at least 64 bytes")
  host = google_host || required.("NOOK_HOST")

  if !Regex.match?(~r/\A[a-zA-Z0-9.-]+\z/, host),
    do: raise("NOOK_HOST must be a hostname, without a scheme or path")

  {:ok, bind_ip} =
    System.get_env("NOOK_BIND_IP", "127.0.0.1") |> String.to_charlist() |> :inet.parse_address()

  config :nook, NookWeb.Endpoint,
    secret_key_base: secret,
    server: System.get_env("PHX_SERVER") == "true",
    url: [host: host, scheme: "https", port: 443],
    http: [ip: bind_ip, port: String.to_integer(System.get_env("PORT", "4000"))],
    check_origin: ["https://#{host}"]

  database_url = required.("DATABASE_URL")

  config :nook, Nook.Repo,
    url: database_url,
    port: URI.parse(database_url).port || 5432,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    idle_interval: String.to_integer(System.get_env("DB_IDLE_INTERVAL", "15000")),
    ssl:
      if(System.get_env("DATABASE_SSL", "true") == "true",
        do: [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ],
        else: false
      )

  config :nook, :launch_limits, true
  config :nook, :board_max_bytes, 8_000_000

  config :nook,
         :expiry_interval_ms,
         String.to_integer(System.get_env("NOOK_EXPIRY_INTERVAL_MS", "60000"))

  email_enabled = auth_mode == "email"

  if email_enabled do
    relay = required.("SMTP_HOST")
    config :nook, :mail_from, required.("MAIL_FROM")

    config :nook, Nook.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: relay,
      port: String.to_integer(System.get_env("SMTP_PORT", "587")),
      username: required.("SMTP_USERNAME"),
      password: required.("SMTP_PASSWORD"),
      auth: :always,
      tls: :always,
      ssl: false,
      tls_options: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        server_name_indication: String.to_charlist(relay),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
  end
end
