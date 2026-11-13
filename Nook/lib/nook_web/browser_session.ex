defmodule NookWeb.BrowserSession do
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _) do
    if Application.get_env(:nook, :dev_routes, false) && conn.host == "localhost" &&
         conn.method == "GET" do
      conn
      |> Phoenix.Controller.redirect(
        external: "http://127.0.0.1:#{conn.port}#{Phoenix.Controller.current_path(conn)}"
      )
      |> halt()
    else
      ensure_guest(conn)
    end
  end

  defp ensure_guest(conn) do
    case get_session(conn, :guest_id) do
      id when is_binary(id) and byte_size(id) == 43 -> conn
      _ -> put_session(conn, :guest_id, Nook.Access.secret())
    end
  end
end
