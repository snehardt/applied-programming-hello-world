defmodule NookWeb.BoardLifecycleTest do
  use NookWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Nook.AccountsFixtures
  alias Nook.{Access, Boards}

  defp browser(conn, actor),
    do: init_test_session(conn, %{guest_id: actor.guest_id, user_token: actor.user_token})

  test "join form submits a session-bound request and redirects after approval", %{conn: conn} do
    owner = Access.new_guest()
    visitor = Access.new_guest()
    code = Boards.create(owner)["code"]
    Nook.Rooms.set_open(code, owner, true)
    {:ok, view, _} = conn |> browser(visitor) |> live("/")
    view |> form("#join-form", %{code: code, name: "Alex"}) |> render_submit()
    assert_push_event(view, "nook:admission", %{id: id, name: "Alex", status: "pending"})
    assert {:error, :not_found} = Boards.get(code, visitor)
    Nook.Rooms.decide(code, id, owner, "approved")
    view |> form("#join-form", %{code: code, name: "Alex"}) |> render_submit()
    assert_redirect(view, "/b/#{code}")
  end

  test "dashboard requires a signed-in account", %{conn: conn} do
    assert conn |> get("/dashboard") |> redirected_to() == "/users/log-in"
  end

  test "authenticated dashboard creates, renames, deletes and restores owned permanent boards", %{
    conn: conn
  } do
    user = user_fixture()
    actor = %{Access.new_guest() | user_token: Nook.Accounts.generate_user_session_token(user)}
    conn = browser(conn, actor)
    {:ok, view, _} = live(conn, "/dashboard")
    view |> element("button", "+ New board") |> render_click()
    {path, _} = assert_redirect(view)
    code = String.replace_prefix(path, "/b/", "")
    {:ok, board} = Boards.get(code, actor)
    assert board["kind"] == "permanent"
    {:ok, view, _} = live(conn, "/dashboard")
    view |> form("#board-#{code} form", %{title: "Game design", code: code}) |> render_submit()
    assert render(view) =~ "Game design"
    view |> element("#board-#{code} button[phx-click=delete]") |> render_click()
    refute has_element?(view, "#board-#{code}")
    assert has_element?(view, "button[phx-click=restore]")
    view |> element("button[phx-click=restore]") |> render_click()
    assert has_element?(view, "#board-#{code}")
  end

  test "an invitation grants browser access but a plain code does not", %{conn: conn} do
    owner = Access.new_guest()
    code = Boards.create(owner)["code"]
    {:ok, token} = Boards.manage(:issue_invite, code, owner)
    conn = browser(conn, Access.new_guest())
    denied = get(conn, "/api/boards/#{code}")
    assert denied.status == 404
    accepted = conn |> recycle() |> get("/invite/#{code}/#{token}")
    assert redirected_to(accepted) == "/b/#{code}"
    saved = accepted |> recycle() |> get("/api/boards/#{code}") |> json_response(200)
    refute saved["can_manage"]
    refute saved["can_claim"]
    refute Map.has_key?(saved, "invite_hash")
    refute Map.has_key?(saved, "guest_owner_hash")
  end

  test "guest identity and return path survive registration and login so claiming works", %{
    conn: conn
  } do
    guest = Access.new_guest()
    code = Boards.create(guest)["code"]
    conn = browser(conn, guest) |> get("/save/#{code}")
    assert redirected_to(conn) == "/users/register"
    assert get_session(conn, :user_return_to) == "/b/#{code}"
    user = user_fixture()
    {token, _} = generate_user_magic_link_token(user)
    signed_in = conn |> recycle() |> post("/users/log-in", %{user: %{token: token}})
    assert get_session(signed_in, :guest_id) == guest.guest_id
    assert redirected_to(signed_in) == "/b/#{code}"
    {:ok, view, html} = live(recycle(signed_in), "/b/#{code}")
    assert html =~ "Keep this board"
    view |> element("#claim-board") |> render_click()
    assert_redirect(view, "/b/#{code}")
    actor = Access.from_session(get_session(signed_in))
    assert {:ok, %{"kind" => "permanent"}} = Boards.get(code, actor)
  end

  test "forging a dashboard event cannot delete another user's board", %{conn: conn} do
    owner = user_fixture()

    owner_actor = %{
      Access.new_guest()
      | user_token: Nook.Accounts.generate_user_session_token(owner)
    }

    code = Boards.create(owner_actor, :permanent)["code"]
    {:ok, view, _} = conn |> log_in_user(user_fixture()) |> live("/dashboard")
    render_click(view, "delete", %{code: code})
    assert {:ok, _} = Boards.get(code, owner_actor)
  end
end
