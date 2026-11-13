defmodule NookWeb.GoogleAuthController do
  use NookWeb, :controller
  alias Nook.{Accounts, GoogleAuth}
  alias NookWeb.UserAuth

  def request(conn, _) do
    if GoogleAuth.configured?() do
      case GoogleAuth.strategy().authorize_url(GoogleAuth.config()) do
        {:ok, %{url: url, session_params: params}} ->
          conn
          |> put_session(:google_oauth, %{
            params: params,
            started: System.system_time(:second),
            user_id: current_id(conn)
          })
          |> redirect(external: url)

        _ ->
          failed(conn)
      end
    else
      conn
      |> put_flash(
        :error,
        "Google sign-in is not available yet. You can still use a quick board."
      )
      |> redirect(to: "/users/log-in")
    end
  end

  def callback(conn, params) do
    flow = get_session(conn, :google_oauth)
    conn = delete_session(conn, :google_oauth)

    with true <- GoogleAuth.configured?(),
         %{params: session_params, started: started, user_id: user_id} <- flow,
         true <- is_integer(started) and (System.system_time(:second) - started) in 0..300,
         true <- user_id == current_id(conn),
         state when is_binary(state) <- params["state"],
         expected when is_binary(expected) <- session_params[:state],
         true <- Plug.Crypto.secure_compare(state, expected),
         {:ok, %{user: claims}} <-
           GoogleAuth.strategy().callback(
             Keyword.put(GoogleAuth.config(), :session_params, session_params),
             params
           ),
         {:ok, user} <- Accounts.sign_in_with_google(claims, current_user(conn)) do
      user = %{user | authenticated_at: NaiveDateTime.utc_now(:second)}

      conn
      |> put_flash(:info, "Welcome to Nook!")
      |> UserAuth.log_in_user(user, %{"remember_me" => "true"})
    else
      {:error, :link_required} ->
        conn
        |> put_flash(
          :error,
          "Sign in to your existing Nook account first, then choose Continue with Google to connect it."
        )
        |> redirect(to: "/users/log-in")

      _ ->
        failed(conn)
    end
  end

  defp current_user(conn), do: get_in(conn.assigns, [:current_scope, Access.key(:user)])
  defp current_id(conn), do: current_user(conn) && current_user(conn).id

  defp failed(conn),
    do:
      conn
      |> delete_session(:google_oauth)
      |> put_flash(
        :error,
        "Google sign-in was cancelled or could not be verified. Please try again."
      )
      |> redirect(to: "/users/log-in")
end
