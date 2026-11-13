defmodule NookWeb.HealthController do
  use NookWeb, :controller
  def live(conn, _), do: json(put_resp_header(conn, "cache-control", "no-store"), %{status: "ok"})

  def ready(conn, _) do
    case Ecto.Adapters.SQL.query(Nook.Repo, "SELECT 1", [], timeout: 2_000) do
      {:ok, _} -> json(put_resp_header(conn, "cache-control", "no-store"), %{status: "ready"})
      _ -> unavailable(conn)
    end
  rescue
    _ -> unavailable(conn)
  catch
    :exit, _ -> unavailable(conn)
  end

  defp unavailable(conn),
    do:
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_status(503)
      |> json(%{status: "unavailable"})
end
