defmodule NookWeb.BoardLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint NookWeb.Endpoint
  setup do
    Process.put(:board_actor, Nook.Access.new_guest())
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Nook.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Nook.Repo, {:shared, self()})
    :ok
  end

  defp actor, do: Process.get(:board_actor)
  defp guest_conn, do: build_conn() |> init_test_session(%{guest_id: actor().guest_id})

  test "landing page is a LiveView and creates a persisted Nook board" do
    {:ok, view, html} = live(guest_conn(), "/")
    assert html =~ "Nook"
    assert html =~ "Whiteboard"
    assert html =~ "nook-logo.png"
    view |> element("button[phx-click=create_board]", "Start a quick board") |> render_click()
    {path, _flash} = assert_redirect(view)
    code = String.replace_prefix(path, "/b/", "")
    assert {:ok, %{"title" => "Untitled board"}} = Nook.Boards.get(code, actor())
  end

  test "board interface contains shape choices and retains toolbar controls" do
    code = Nook.Boards.create(actor())["code"]
    {:ok, view, html} = live(guest_conn(), "/b/#{code}")
    assert has_element?(view, "#nook-ui[phx-hook=Whiteboard]")

    for shape <- ~w(rectangle rounded circle triangle diamond) do
      assert html =~ "data-shape=\"#{shape}\""
    end

    assert html =~ "Text size"
    assert has_element?(view, "#attach-file")
  end

  test "joining unknown rooms gives a useful message without creating a board" do
    {:ok, view, _} = live(guest_conn(), "/")
    view |> form("#join-form", %{code: "NOTAROOM"}) |> render_submit()
    assert_push_event(view, "nook:toast", %{message: message})
    assert message =~ "could not be found"
  end
end
