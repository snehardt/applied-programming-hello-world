defmodule NookWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint NookWeb.Endpoint
      use NookWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import NookWeb.ConnCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Nook.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def register_and_log_in_user(%{conn: conn} = context) do
    user = Nook.AccountsFixtures.user_fixture()
    opts = context |> Map.take([:token_authenticated_at]) |> Enum.into([])
    %{conn: log_in_user(conn, user, opts), user: user, scope: Nook.Accounts.Scope.for_user(user)}
  end

  def log_in_user(conn, user, opts \\ []) do
    token = Nook.Accounts.generate_user_session_token(user)

    if opts[:token_authenticated_at],
      do:
        Nook.AccountsFixtures.override_token_authenticated_at(
          token,
          opts[:token_authenticated_at]
        )

    conn |> Phoenix.ConnTest.init_test_session(%{}) |> Plug.Conn.put_session(:user_token, token)
  end
end
