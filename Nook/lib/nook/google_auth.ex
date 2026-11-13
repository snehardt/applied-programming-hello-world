defmodule Nook.GoogleAuth do
  @moduledoc "Google OpenID Connect. Tokens are validated by Assent and never persisted."
  def email_enabled?, do: Application.get_env(:nook, :email_auth_enabled, true)

  def configured? do
    config = Application.get_env(:nook, :google_oauth, [])

    Enum.all?(
      [:client_id, :client_secret, :redirect_uri],
      &(is_binary(config[&1]) and config[&1] != "")
    )
  end

  def config do
    Application.get_env(:nook, :google_oauth, [])
    |> Keyword.merge(
      openid_configuration: %{
        "issuer" => "https://accounts.google.com",
        "authorization_endpoint" => "https://accounts.google.com/o/oauth2/v2/auth",
        "token_endpoint" => "https://oauth2.googleapis.com/token",
        "userinfo_endpoint" => "https://openidconnect.googleapis.com/v1/userinfo",
        "jwks_uri" => "https://www.googleapis.com/oauth2/v3/certs",
        "id_token_signing_alg_values_supported" => ["RS256"]
      },
      nonce: Nook.Access.secret(),
      code_verifier: true,
      authorization_params: [scope: "email", prompt: "select_account"],
      http_adapter:
        {Assent.HTTPAdapter.Httpc,
         [
           timeout: 10_000,
           connect_timeout: 5_000,
           ssl: [
             verify: :verify_peer,
             cacerts: :public_key.cacerts_get(),
             customize_hostname_check: [
               match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
             ]
           ]
         ]}
    )
  end

  def strategy, do: Application.get_env(:nook, :google_strategy, Assent.Strategy.Google)
end
