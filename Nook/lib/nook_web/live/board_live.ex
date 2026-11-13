defmodule NookWeb.BoardLive do
  use NookWeb, :live_view
  embed_templates("board_live/*")

  def mount(params, session, socket) do
    actor = Nook.Access.from_session(session)

    socket =
      assign(socket,
        page_title: "Nook — Bring ideas together",
        code: params["code"],
        actor: actor,
        board: nil,
        guest_days: Application.get_env(:nook, :guest_inactivity_days, 7)
      )

    if code = params["code"] do
      case Nook.Boards.get(code, actor) do
        {:ok, board} ->
          {:ok, assign(socket, board: board)}

        _ ->
          {:ok,
           socket
           |> put_flash(
             :error,
             "Board unavailable. Ask for an invitation or log in to the owner account."
           )
           |> redirect(to: "/")}
      end
    else
      {:ok, socket}
    end
  end

  def render(assigns), do: board(assigns)

  def handle_event("create_board", _, socket) do
    case Nook.Boards.create(socket.assigns.actor) do
      %{"code" => code} -> {:noreply, redirect(socket, to: "/b/#{code}")}
      _ -> {:noreply, put_flash(socket, :error, "Please wait before creating another board.")}
    end
  end

  def handle_event("join_room", %{"code" => raw} = params, socket) do
    path =
      case URI.parse(String.trim(raw)) do
        %URI{path: path} -> path || ""
      end

    case String.split(path, "/", trim: true) do
      [kind, code, token] when kind in ["invite", "recover"] ->
        mode = if kind == "invite", do: :invite, else: :recovery

        case Nook.Boards.Store.redeem(code, token, socket.assigns.actor, mode) do
          {:ok, :ok} -> {:noreply, redirect(socket, to: "/b/#{code}")}
          _ -> join_error(socket)
        end

      parts ->
        code = (List.last(parts) || "") |> String.upcase()

        case Nook.Boards.get(code, socket.assigns.actor) do
          {:ok, _} ->
            {:noreply, redirect(socket, to: "/b/#{code}")}

          _ ->
            case Nook.Rooms.request(code, socket.assigns.actor, params["name"]) do
              {:ok, request} -> {:noreply, push_event(socket, "nook:admission", request)}
              _ -> join_error(socket)
            end
        end
    end
  end

  def handle_event("claim_board", _, socket) do
    case Nook.Boards.manage(:claim, socket.assigns.code, socket.assigns.actor) do
      {:ok, :ok} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Saved permanently to your boards. Previous invitations have been revoked."
         )
         |> redirect(to: "/b/#{socket.assigns.code}")}

      _ ->
        {:noreply,
         push_event(socket, "nook:toast", %{
           message: "Only the creator can save an unexpired quick board after logging in."
         })}
    end
  end

  def handle_event("create_invite", _, socket) do
    case Nook.Boards.manage(:issue_invite, socket.assigns.code, socket.assigns.actor) do
      {:ok, token} ->
        {:noreply,
         push_event(socket, "nook:invite", %{path: "/invite/#{socket.assigns.code}/#{token}"})}

      _ ->
        {:noreply,
         push_event(socket, "nook:toast", %{
           message: "Only the owner can create invitation links."
         })}
    end
  end

  def handle_event("disable_sharing", _, socket) do
    case Nook.Boards.manage(:disable_sharing, socket.assigns.code, socket.assigns.actor) do
      {:ok, :ok} ->
        {:noreply, push_event(socket, "nook:invite", %{path: nil})}

      _ ->
        {:noreply, push_event(socket, "nook:toast", %{message: "Sharing could not be changed."})}
    end
  end

  defp join_error(socket),
    do:
      {:noreply,
       push_event(socket, "nook:toast", %{
         message:
           "This room could not be found or you do not have access. Ask its owner for an invitation link."
       })}
end
