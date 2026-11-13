defmodule NookWeb.GoogleAuthTest.Strategy do
  def authorize_url(config), do: Assent.Strategy.Google.authorize_url(config)

  def callback(config, params) do
    send(self(), {:provider_called, config[:session_params]})

    case params["code"] do
      "valid" ->
        {:ok,
         %{
           user: %{
             "sub" => "google-test-sub",
             "email" => "google@example.com",
             "email_verified" => true
           }
         }}

      "unverified" ->
        {:ok, %{user: %{"sub" => "bad", "email" => "bad@example.com", "email_verified" => false}}}

      _ ->
        {:error, :invalid_token}
    end
  end
end

defmodule NookWeb.GoogleAuthTest do
  use NookWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    keys = [:google_oauth, :google_strategy, :email_auth_enabled]
    old = Map.new(keys, &{&1, Application.get_env(:nook, &1)})

    Application.put_env(:nook, :google_oauth,
      client_id: "test-client",
      client_secret: "test-secret",
      redirect_uri: "http://127.0.0.1:4000/auth/google/callback"
    )

    Application.put_env(:nook, :google_strategy, NookWeb.GoogleAuthTest.Strategy)

    on_exit(fn ->
      Enum.each(old, fn {key, value} ->
        if is_nil(value),
          do: Application.delete_env(:nook, key),
          else: Application.put_env(:nook, key, value)
      end)
    end)

    :ok
  end

  test "Google-only pages offer Google and hide email forms", %{conn: conn} do
    Application.put_env(:nook, :email_auth_enabled, false)
    {:ok, login, html} = live(conn, "/users/log-in")
    assert html =~ "Continue with Google"
    refute has_element?(login, "#login_form_magic")
    refute has_element?(login, "#login_form_password")
    {:ok, registration, _} = live(conn, "/users/register")
    refute has_element?(registration, "#registration_form")

    result =
      post(conn, "/users/log-in", %{"user" => %{"email" => "x@example.com", "password" => "x"}})

    assert redirected_to(result) == "/users/log-in"
    refute get_session(result, :user_token)
  end

  test "authorization uses state, nonce, PKCE and a fixed callback", %{conn: conn} do
    conn = post(conn, "/auth/google")
    location = redirected_to(conn)
    query = URI.decode_query(URI.parse(location).query)
    assert URI.parse(location).host == "accounts.google.com"
    assert query["redirect_uri"] == "http://127.0.0.1:4000/auth/google/callback"
    assert query["scope"] == "openid email"
    assert query["code_challenge_method"] == "S256"
    assert byte_size(query["nonce"]) > 20
    assert get_session(conn, :google_oauth).params.state == query["state"]
  end

  test "callback creates a session, preserves guest ownership and consumes the flow", %{
    conn: conn
  } do
    start = post(conn, "/auth/google")
    flow = get_session(start, :google_oauth)
    guest_id = get_session(start, :guest_id)

    done =
      start
      |> recycle()
      |> get("/auth/google/callback", %{"state" => flow.params.state, "code" => "valid"})

    assert redirected_to(done) == "/dashboard"
    assert get_session(done, :user_token)
    assert get_session(done, :guest_id) == guest_id
    refute get_session(done, :google_oauth)
    assert_received {:provider_called, %{nonce: _, code_verifier: _}}

    replay =
      done
      |> recycle()
      |> get("/auth/google/callback", %{"state" => flow.params.state, "code" => "valid"})

    assert redirected_to(replay) == "/users/log-in"
    refute_received {:provider_called, _}
  end

  test "bad state, expired flow and rejected identity cannot sign in", %{conn: conn} do
    for kind <- [:state, :expired, :unverified] do
      start = post(conn, "/auth/google")
      flow = get_session(start, :google_oauth)

      flow =
        if kind == :expired, do: %{flow | started: System.system_time(:second) - 301}, else: flow

      session = start |> recycle() |> init_test_session(%{google_oauth: flow})

      result =
        get(session, "/auth/google/callback", %{
          "state" => if(kind == :state, do: "wrong", else: flow.params.state),
          "code" => if(kind == :unverified, do: "unverified", else: "valid")
        })

      refute get_session(result, :user_token)
      assert redirected_to(result) == "/users/log-in"
      if kind != :unverified, do: refute_received({:provider_called, _})
    end
  end
end
