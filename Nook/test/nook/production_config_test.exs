defmodule Nook.ProductionConfigTest do
  use ExUnit.Case, async: false

  @keys ~w(SECRET_KEY_BASE NOOK_HOST DATABASE_URL SMTP_HOST SMTP_USERNAME SMTP_PASSWORD MAIL_FROM PHX_SERVER NOOK_BIND_IP DATABASE_SSL)
  setup do
    previous = Map.new(@keys, &{&1, System.get_env(&1)})

    System.put_env(%{
      "SECRET_KEY_BASE" => String.duplicate("s", 64),
      "NOOK_HOST" => "nook.example.test",
      "DATABASE_URL" => "ecto://nook:example@localhost/nook",
      "SMTP_HOST" => "smtp.example.test",
      "SMTP_USERNAME" => "example",
      "SMTP_PASSWORD" => "example",
      "MAIL_FROM" => "nook@example.test",
      "PHX_SERVER" => "false",
      "NOOK_BIND_IP" => "127.0.0.1",
      "DATABASE_SSL" => "true"
    })

    on_exit(fn ->
      Enum.each(previous, fn {key, value} ->
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end)
    end)
  end

  defp config, do: Config.Reader.read!("config/runtime.exs", env: :prod)

  test "production database URLs override the local development port" do
    System.put_env("DATABASE_URL", "postgresql://nook:example@database.example/nook")
    assert config()[:nook][Nook.Repo][:port] == 5432
    System.put_env("DATABASE_URL", "postgresql://nook:example@database.example:6543/nook")
    assert config()[:nook][Nook.Repo][:port] == 6543
  end

  test "production requires a strong secret and explicit host" do
    System.delete_env("SECRET_KEY_BASE")
    assert_raise RuntimeError, ~r/SECRET_KEY_BASE/, &config/0
    System.put_env("SECRET_KEY_BASE", "short")
    assert_raise RuntimeError, ~r/64 bytes/, &config/0
    System.put_env("SECRET_KEY_BASE", String.duplicate("s", 64))
    System.put_env("NOOK_HOST", "https://bad.test/path")
    assert_raise RuntimeError, ~r/hostname/, &config/0
  end

  test "production stays loopback until deliberately enabled and uses verified TLS" do
    cfg = config()[:nook]
    endpoint = cfg[NookWeb.Endpoint]
    assert endpoint[:server] == false
    assert endpoint[:http][:ip] == {127, 0, 0, 1}
    assert endpoint[:url][:scheme] == "https"
    assert endpoint[:check_origin] == ["https://nook.example.test"]
    assert cfg[Nook.Repo][:ssl][:verify] == :verify_peer
    assert cfg[Nook.Mailer][:tls] == :always
    assert cfg[Nook.Mailer][:tls_options][:verify] == :verify_peer
    System.delete_env("SMTP_PASSWORD")
    assert_raise RuntimeError, ~r/SMTP_PASSWORD/, &config/0
  end
end
