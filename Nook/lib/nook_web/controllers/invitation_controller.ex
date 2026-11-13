defmodule NookWeb.InvitationController do
  use NookWeb, :controller
  def accept(conn, params), do: redeem(conn, params, :invite)
  def recover(conn, params), do: redeem(conn, params, :recovery)

  defp redeem(conn, %{"code" => code, "token" => token}, mode) do
    actor = Nook.Access.from_session(get_session(conn))

    case Nook.Boards.Store.redeem(code, token, actor, mode) do
      {:ok, :ok} ->
        redirect(conn, to: "/b/#{code}")

      _ ->
        conn
        |> put_flash(:error, "This link is invalid, expired, or no longer shared.")
        |> redirect(to: "/")
    end
  end
end
