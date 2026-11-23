defmodule NookWeb.PolishTest do
  use NookWeb.ConnCase, async: true

  test "health probes expose status only and readiness checks the database", %{conn: conn} do
    assert json_response(get(conn, "/health/live"), 200) == %{"status" => "ok"}
    assert json_response(get(conn, "/health/ready"), 200) == %{"status" => "ready"}
  end

  test "browser pages include restrictive resource policy and accessible recovery UI", %{
    conn: conn
  } do
    conn = get(conn, "/")
    assert [policy] = get_resp_header(conn, "content-security-policy")
    assert policy =~ "frame-ancestors 'none'"
    assert policy =~ "object-src 'none'"
    html = html_response(conn, 200)

    for marker <- [
          "Skip to content",
          "retry-load",
          "aria-labelledby=\"room-dialog-title\"",
          "board-load-state",
          "noscript"
        ] do
      assert html =~ marker
    end
  end

  test "error pages offer navigation without leaking exception details" do
    html =
      NookWeb.ErrorHTML.render("500.html", %{reason: "private database credentials"})
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    assert html =~ "Back to home"
    assert html =~ "Internal Server Error"
    refute html =~ "private database credentials"
  end
end
