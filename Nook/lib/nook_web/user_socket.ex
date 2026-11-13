defmodule NookWeb.UserSocket do
  use Phoenix.Socket
  channel("board:*", NookWeb.BoardChannel)

  def connect(%{"socket_token" => token}, socket, _) when is_binary(token) do
    case Phoenix.Token.decrypt(NookWeb.Endpoint, "nook-socket", token, max_age: 60) do
      {:ok, %{guest_id: guest_id, user_token: user_token}}
      when is_binary(guest_id) and byte_size(guest_id) == 43 ->
        actor = %Nook.Access{guest_id: guest_id, user_token: user_token}
        {:ok, socket |> assign(:actor, actor) |> assign(:visitor_id, Nook.Access.secret())}

      _ ->
        :error
    end
  end

  def connect(_, socket, %{session: session}) when is_map(session) do
    actor = Nook.Access.from_session(session)

    if is_binary(actor.guest_id) do
      {:ok, socket |> assign(:actor, actor) |> assign(:visitor_id, Nook.Access.secret())}
    else
      :error
    end
  end

  def connect(_, _, _), do: :error

  def id(%{assigns: %{actor: %{user_token: token}}}) when is_binary(token),
    do: "users_sessions:#{Base.url_encode64(token)}"

  def id(_), do: nil
end

defmodule NookWeb.Presence do
  use Phoenix.Presence, otp_app: :nook, pubsub_server: Nook.PubSub
end

defmodule NookWeb.BoardChannel do
  use Phoenix.Channel

  intercept(
    ~w(operation preview access_changed presence_diff room_requests_changed cursor previews drawing)
  )

  def join("board:" <> code, params, socket) do
    case Nook.Boards.get(code, socket.assigns.actor) do
      {:ok, board} ->
        send(self(), :after_join)
        profile = Nook.Participants.profile(code, socket.assigns.actor, params["name"])

        {:ok,
         board |> Map.put("self", profile) |> Map.put("cursor_id", socket.assigns.visitor_id),
         socket |> assign(:code, code) |> assign(:profile, profile)}

      _ ->
        {:error, %{reason: "Board not found"}}
    end
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      NookWeb.Presence.track(
        socket,
        socket.assigns.profile.id,
        socket.assigns.profile
        |> Map.put(:online_at, System.system_time(:second))
        |> Map.put(:cursor_id, socket.assigns.visitor_id)
      )

    push(socket, "presence_state", NookWeb.Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in(event, payload, socket) do
    if Nook.RateLimit.allow?({:channel, socket.assigns.actor.guest_id}, 80, 1000),
      do: handle_allowed_in(event, payload, socket),
      else: {:reply, {:error, %{reason: "rate_limited", retry_after_ms: 1000}}, socket}
  end

  defp handle_allowed_in("operation", op, socket) do
    case Nook.Boards.apply_op(socket.assigns.code, op, socket.assigns.actor) do
      {:ok, revision} ->
        case Nook.Boards.get(socket.assigns.code, socket.assigns.actor) do
          {:ok, snapshot} -> {:reply, {:ok, %{revision: revision, snapshot: snapshot}}, socket}
          _ -> {:reply, {:error, %{reason: :not_found}}, socket}
        end

      {:error, {:conflict, snapshot}} ->
        {:reply, {:error, %{reason: "conflict", snapshot: snapshot}}, socket}

      {:error, :rate_limited} ->
        {:reply, {:error, %{reason: "rate_limited", retry_after_ms: 60000}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  defp handle_allowed_in("set_name", %{"name" => name}, socket) do
    if Nook.Boards.Store.authorized?(socket.assigns.code, socket.assigns.actor) do
      profile = Nook.Participants.profile(socket.assigns.code, socket.assigns.actor, name)

      NookWeb.Presence.update(
        socket,
        profile.id,
        profile
        |> Map.put(:online_at, System.system_time(:second))
        |> Map.put(:cursor_id, socket.assigns.visitor_id)
      )

      {:reply, {:ok, profile}, assign(socket, :profile, profile)}
    else
      {:reply, {:error, %{reason: :not_found}}, socket}
    end
  end

  defp handle_allowed_in("preview", payload, socket) do
    if valid_preview?(payload) and
         Nook.Boards.Store.authorized?(socket.assigns.code, socket.assigns.actor, :write),
       do: broadcast_from!(socket, "preview", Map.take(payload, ~w(id changes)))

    {:noreply, socket}
  end

  defp handle_allowed_in("previews", %{"elements" => elements}, socket) when is_list(elements) do
    if length(elements) in 1..100 and Enum.all?(elements, &valid_preview?/1) and
         Nook.Boards.Store.authorized?(socket.assigns.code, socket.assigns.actor, :write) do
      broadcast_from!(socket, "previews", %{
        elements: Enum.map(elements, &Map.take(&1, ~w(id changes)))
      })
    end

    {:noreply, socket}
  end

  defp handle_allowed_in("drawing", %{"visible" => visible} = payload, socket)
       when is_boolean(visible) do
    now = System.monotonic_time(:millisecond)
    points = payload["points"]

    valid =
      not visible or
        (is_binary(payload["color"]) and Regex.match?(~r/^#[0-9a-fA-F]{6}$/, payload["color"]) and
           is_integer(payload["width"]) and payload["width"] in 1..24 and
           is_list(points) and length(points) in 1..128 and
           Enum.all?(points, fn
             [x, y] ->
               is_number(x) and is_number(y) and abs(x) < 10_000_000 and abs(y) < 10_000_000

             _ ->
               false
           end))

    if valid and (not visible or now - Map.get(socket.assigns, :drawing_at, now - 100) >= 50) and
         Nook.Boards.Store.authorized?(socket.assigns.code, socket.assigns.actor) do
      broadcast_from!(
        socket,
        "drawing",
        Map.merge(Map.take(payload, ~w(visible color width points)), %{
          "id" => socket.assigns.visitor_id
        })
      )

      {:noreply, assign(socket, :drawing_at, now)}
    else
      {:noreply, socket}
    end
  end

  defp handle_allowed_in("cursor", %{"visible" => visible} = payload, socket)
       when is_boolean(visible) do
    now = System.monotonic_time(:millisecond)
    last = Map.get(socket.assigns, :cursor_at, now - 100)
    x = payload["x"]
    y = payload["y"]

    valid =
      not visible or
        (is_number(x) and is_number(y) and abs(x) < 10_000_000 and abs(y) < 10_000_000)

    if valid and (not visible or now - last >= 33) and
         Nook.Boards.Store.authorized?(socket.assigns.code, socket.assigns.actor) do
      broadcast_from!(socket, "cursor", %{
        id: socket.assigns.visitor_id,
        participant_id: socket.assigns.profile.id,
        name: socket.assigns.profile.name,
        color: socket.assigns.profile.color,
        visible: visible,
        x: if(visible, do: x),
        y: if(visible, do: y)
      })

      {:noreply, assign(socket, :cursor_at, now)}
    else
      {:noreply, socket}
    end
  end

  defp handle_allowed_in(_, _, socket), do: {:reply, {:error, %{reason: "invalid"}}, socket}

  defp valid_preview?(%{"id" => id, "changes" => changes})
       when is_binary(id) and byte_size(id) in 1..64 and is_map(changes) do
    map_size(changes) in 1..4 and
      Enum.all?(changes, fn
        {k, v} when k in ~w(x y) -> is_number(v) and abs(v) < 10_000_000
        {k, v} when k in ~w(w h) -> is_number(v) and v >= 50 and v <= 10_000
        _ -> false
      end)
  end

  defp valid_preview?(_), do: false

  def handle_out(event, payload, socket) do
    if Nook.Boards.Store.authorized?(socket.assigns.code, socket.assigns.actor) do
      push(socket, event, payload)
      {:noreply, socket}
    else
      push(socket, "access_lost", %{
        message: "This board expired, was deleted, or your access changed."
      })

      {:stop, :normal, socket}
    end
  end
end
