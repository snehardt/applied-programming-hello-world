defmodule NookWeb.DashboardLive do
  use NookWeb, :live_view
  alias Nook.Boards

  def mount(_, session, socket) do
    {:ok,
     socket
     |> assign(actor: Nook.Access.from_session(session), page_title: "My boards — Nook")
     |> load_boards()}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="dashboard">
        <div class="dashboard-intro"><div><h1>Boards</h1><p>Your saved boards.</p></div><button class="primary" phx-click="new_board">+ New board</button></div>
        <div class="board-grid">
          <p :if={@boards == []} class="empty-library">No saved boards yet. Create a board to get started.</p>
          <article :for={board <- @boards} id={"board-#{board.code}"} class="board-card">
            <a class="board-card-open" href={"/b/#{board.code}"}><span class="board-card-art" aria-hidden="true"><svg viewBox="0 0 150 85" fill="none"><rect x="13" y="15" width="48" height="52" rx="2"/><path d="M23 30h27M23 41h18M23 52h22M70 48c12-17 25-18 40-16m-7-5 8 5-6 6"/><circle cx="126" cy="23" r="12"/></svg></span><strong>{board.title}</strong><span>{if Nook.Rooms.shared?(board), do: "Shared with guests", else: "Private"} · Updated {Calendar.strftime(board.updated_at, "%b %d")}</span></a>
            <details class="board-row-options"><summary aria-label={"Options for #{board.title}"}>•••</summary><form phx-submit="rename"><input type="hidden" name="code" value={board.code} /><label for={"title-#{board.code}"}>Board name</label><div class="rename-row"><input id={"title-#{board.code}"} name="title" aria-label={"Rename #{board.title}"} value={board.title} required maxlength="120" /><button type="submit">Rename</button></div></form>
            <button class="board-delete" phx-click="delete" phx-value-code={board.code} data-confirm="Move this board to Deleted boards? Invitations will stop working.">Delete board</button></details>
          </article>
        </div>
        <section :if={@guest_boards != []} class="guest-library"><h2>Your quick boards</h2><p>These belong to this browser. Save one permanently before it expires.</p>
          <article :for={board <- @guest_boards} class="guest-row"><a href={"/b/#{board.code}"}>{board.title}</a><span>Expires {Calendar.strftime(board.expires_at, "%b %d")}</span><button class="secondary" phx-click="claim" phx-value-code={board.code}>Save permanently</button></article>
        </section>
        <details :if={@deleted != []} class="deleted-library"><summary>Deleted boards ({length(@deleted)})</summary><article :for={board <- @deleted} class="guest-row"><span>{board.title}</span><button class="secondary" phx-click="restore" phx-value-code={board.code}>Restore</button></article></details>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("new_board", _, socket) do
    case Boards.create(socket.assigns.actor, :permanent) do
      %{"code" => code} -> {:noreply, redirect(socket, to: "/b/#{code}")}
      _ -> failed(socket)
    end
  end

  def handle_event("rename", %{"code" => code, "title" => title}, socket) do
    case Boards.apply_op(
           code,
           %{"type" => "rename", "title" => String.trim(title)},
           socket.assigns.actor
         ) do
      {:ok, _} -> {:noreply, load_boards(socket)}
      _ -> failed(socket)
    end
  end

  def handle_event(action, %{"code" => code}, socket)
      when action in ["claim", "delete", "restore"] do
    action =
      case action do
        "claim" -> :claim
        "delete" -> :delete
        "restore" -> :restore
      end

    case Boards.manage(action, code, socket.assigns.actor) do
      {:ok, :ok} ->
        {:noreply, socket |> put_flash(:info, "Your boards have been updated.") |> load_boards()}

      _ ->
        failed(socket)
    end
  end

  defp load_boards(socket) do
    actor = socket.assigns.actor

    assign(socket,
      boards: Boards.Store.list_owned(actor),
      guest_boards: Boards.Store.list_guest(actor),
      deleted: Boards.Store.list_owned(actor, true)
    )
  end

  defp failed(socket),
    do:
      {:noreply,
       put_flash(
         socket,
         :error,
         "This action is unavailable. Sign in again or check that you own the board."
       )}
end
