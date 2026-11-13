defmodule Nook.GoogleTokenTest.HTTP do
  @behaviour Assent.HTTPAdapter
  def request(:get, "https://www.googleapis.com/oauth2/v3/certs", _, _, _) do
    {:ok,
     %Assent.HTTPAdapter.HTTPResponse{
       status: 200,
       headers: [{"content-type", "application/json"}],
       body: Jason.encode!(%{"keys" => [Process.get(:google_jwk)]})
     }}
  end
end

defmodule Nook.GoogleTokenTest do
  use ExUnit.Case, async: true

  test "Google ID tokens require a valid signature, issuer, audience, expiry and nonce" do
    key = :public_key.generate_key({:rsa, 2048, 65_537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
    encode = fn n -> n |> :binary.encode_unsigned() |> Base.url_encode64(padding: false) end

    Process.put(:google_jwk, %{
      "kty" => "RSA",
      "kid" => "test-key",
      "n" => encode.(elem(key, 2)),
      "e" => encode.(elem(key, 3))
    })

    now = System.system_time(:second)

    claims = %{
      "iss" => "https://accounts.google.com",
      "sub" => "google-user",
      "aud" => "test-client",
      "exp" => now + 300,
      "iat" => now,
      "nonce" => "expected-nonce",
      "email" => "user@example.com",
      "email_verified" => true
    }

    config =
      Nook.GoogleAuth.config()
      |> Keyword.merge(
        client_id: "test-client",
        session_params: %{nonce: "expected-nonce"},
        http_adapter: Nook.GoogleTokenTest.HTTP
      )

    sign = fn data ->
      Assent.JWTAdapter.AssentJWT.sign(data, "RS256", pem,
        json_library: Jason,
        private_key_id: "test-key"
      )
    end

    {:ok, token} = sign.(claims)
    assert {:ok, _} = Assent.Strategy.OIDC.validate_id_token(config, token)

    for bad <- [
          %{"iss" => "https://attacker.example"},
          %{"aud" => "wrong-client"},
          %{"exp" => now - 300},
          %{"nonce" => "wrong-nonce"}
        ] do
      {:ok, invalid} = sign.(Map.merge(claims, bad))
      assert {:error, _} = Assent.Strategy.OIDC.validate_id_token(config, invalid)
    end

    [header, _, signature] = String.split(token, ".")

    forged_claims =
      claims |> Map.put("sub", "forged") |> Jason.encode!() |> Base.url_encode64(padding: false)

    assert {:error, _} =
             Assent.Strategy.OIDC.validate_id_token(
               config,
               "#{header}.#{forged_claims}.#{signature}"
             )
  end
end
