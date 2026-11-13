defmodule NookWeb.PageController do
  use NookWeb, :controller

  def create(conn, _) do
    case Nook.Boards.create(Nook.Access.from_session(get_session(conn))) do
      %{"code" => _} = board ->
        json(conn, board)

      {:error, :rate_limited} ->
        conn
        |> put_status(429)
        |> put_resp_header("retry-after", "60")
        |> json(%{error: "Please wait before creating another board"})

      _ ->
        conn |> put_status(403) |> json(%{error: "Board could not be created"})
    end
  end

  def socket_token(conn, _) do
    actor = Nook.Access.from_session(get_session(conn))
    token = Phoenix.Token.encrypt(NookWeb.Endpoint, "nook-socket", Map.from_struct(actor))
    conn |> put_resp_header("cache-control", "no-store") |> json(%{token: token})
  end

  def invite(conn, %{"code" => code}) do
    case Nook.Boards.manage(:issue_invite, code, Nook.Access.from_session(get_session(conn))) do
      {:ok, token} -> json(conn, %{path: "/invite/#{code}/#{token}"})
      _ -> conn |> put_status(404) |> json(%{error: "Board unavailable"})
    end
  end

  def reusable_invite(conn, %{"code" => code}) do
    case Nook.Boards.manage(:ensure_invite, code, Nook.Access.from_session(get_session(conn))) do
      {:ok, token} ->
        json(conn, %{path: "/invite/#{code}/#{token}"})

      {:error, :link_unavailable} ->
        conn
        |> put_status(409)
        |> json(%{
          error:
            "This older invitation cannot be copied here. Use its existing link, or choose Replace invitation in sharing options."
        })

      _ ->
        conn |> put_status(404) |> json(%{error: "Board unavailable"})
    end
  end

  def disable_invites(conn, %{"code" => code}) do
    case Nook.Boards.manage(:disable_sharing, code, Nook.Access.from_session(get_session(conn))) do
      {:ok, :ok} -> json(conn, %{ok: true})
      _ -> conn |> put_status(404) |> json(%{error: "Board unavailable"})
    end
  end

  def board(conn, %{"code" => code}) do
    case Nook.Boards.get(code, Nook.Access.from_session(get_session(conn))) do
      {:ok, board} ->
        json(conn, board)

      _ ->
        conn
        |> put_status(404)
        |> json(%{error: "Board unavailable. Use an invitation or sign in to its owner account."})
    end
  end

  def save_prompt(conn, %{"code" => code}) do
    actor = Nook.Access.from_session(get_session(conn))

    if Nook.Boards.Store.authorized?(code, actor, :manage) do
      conn
      |> put_session(:user_return_to, "/b/#{code}")
      |> redirect(to: if(Nook.Access.user(actor), do: "/b/#{code}", else: "/users/register"))
    else
      conn
      |> put_flash(:error, "Only the creator can keep this quick board.")
      |> redirect(to: "/")
    end
  end
end
