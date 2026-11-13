defmodule NookWeb.RoomController do
  use NookWeb, :controller

  def create(conn, %{"code" => code} = params),
    do: respond(conn, Nook.Rooms.request(code, actor(conn), params["name"]))

  def create(conn, _), do: conn |> put_status(422) |> json(%{error: "Enter a room code."})

  def status(conn, %{"id" => id}), do: respond(conn, Nook.Rooms.status(id, actor(conn)))
  def index(conn, %{"code" => code}), do: respond(conn, Nook.Rooms.list(code, actor(conn)))

  def open(conn, %{"code" => code, "open" => open}) when is_boolean(open),
    do: respond(conn, Nook.Rooms.set_open(code, actor(conn), open))

  def open(conn, _),
    do: conn |> put_status(422) |> json(%{error: "Choose whether requests are open."})

  def decide(conn, %{"code" => code, "id" => id, "decision" => decision})
      when decision in ["approved", "denied"],
      do: respond(conn, Nook.Rooms.decide(code, id, actor(conn), decision))

  def decide(conn, _), do: conn |> put_status(422) |> json(%{error: "Choose Admit or Decline."})

  defp actor(conn), do: Nook.Access.from_session(get_session(conn))
  defp respond(conn, {:ok, result}), do: json(conn, result)

  defp respond(conn, _),
    do: conn |> put_status(404) |> json(%{error: "Room unavailable or requests closed."})
end
