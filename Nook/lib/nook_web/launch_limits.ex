defmodule NookWeb.LaunchLimits do
  import Plug.Conn
  def init(opts), do: opts

  def call(conn, _) do
    if (conn.method == "POST" or conn.request_path == "/auth/google/callback") and
         (String.starts_with?(conn.request_path, "/auth/") or
            String.starts_with?(conn.request_path, "/api/") or
            conn.request_path == "/users/log-in") do
      if Nook.RateLimit.allow?({:http_write, get_session(conn, :guest_id)}, 120, 60_000) and
           Nook.RateLimit.allow?(:http_write_total, 5_000, 60_000),
         do: conn,
         else:
           conn
           |> put_resp_header("retry-after", "60")
           |> send_resp(429, "Please wait a moment before trying again.")
           |> halt()
    else
      conn
    end
  end
end
