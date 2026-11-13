defmodule NookWeb.FailedMailAdapter do
  use Swoosh.Adapter
  def deliver(_, _), do: {:error, :unavailable}
end

defmodule NookWeb.MailFailureTest do
  use NookWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "registration preserves the account and offers retry when mail delivery fails", %{
    conn: conn
  } do
    previous = Application.fetch_env!(:nook, Nook.Mailer)
    Application.put_env(:nook, Nook.Mailer, adapter: NookWeb.FailedMailAdapter)
    on_exit(fn -> Application.put_env(:nook, Nook.Mailer, previous) end)
    {:ok, view, _} = live(conn, "/users/register")
    email = "delivery-#{System.unique_integer([:positive])}@example.test"
    view |> form("#registration_form", user: %{email: email}) |> render_submit()
    {path, flash} = assert_redirect(view)
    assert path == "/users/log-in"
    assert flash["error"] =~ "account was created"
    assert Nook.Accounts.get_user_by_email(email)
  end
end
