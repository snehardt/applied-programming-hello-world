defmodule Nook.Boards do
  @moduledoc "Validated board operations. PostgreSQL commits precede acknowledgements and broadcasts."
  use GenServer
  @types ~w(text note shape task idea icon file connection stroke)
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def create(actor, kind \\ :guest) do
    if Nook.RateLimit.allow?({:new_board, actor.guest_id}, 20, 3_600_000) and
         Nook.RateLimit.allow?(:new_board_total, 500, 3_600_000),
       do: GenServer.call(__MODULE__, {:create, actor, kind}),
       else: {:error, :rate_limited}
  end

  def get(code, actor), do: GenServer.call(__MODULE__, {:get, code, actor})

  def apply_op(code, op, actor) when is_map(op),
    do: GenServer.call(__MODULE__, {:op, code, op, actor})

  def apply_op(_, _, _), do: {:error, :invalid}

  def manage(action, code, actor)
      when action in [:claim, :issue_invite, :ensure_invite, :disable_sharing, :delete, :restore],
      do: GenServer.call(__MODULE__, {:manage, action, code, actor})

  def init(_), do: {:ok, nil}

  def handle_call({:create, actor, kind}, _, table) do
    code = :crypto.strong_rand_bytes(8) |> Base.encode32(padding: false)
    board = Nook.Boards.Store.create(code, actor, kind)
    {:reply, board, table}
  end

  def handle_call({:get, code, actor}, _, table),
    do: {:reply, Nook.Boards.Store.get(code, actor), table}

  def handle_call({:op, code, op, actor}, _, table) do
    result =
      Nook.Boards.Store.transact(
        code,
        actor,
        fn board ->
          with :ok <- operation_allowed(actor),
               :new <- check_replay(board, op),
               :ok <- check_version(board, op),
               {:ok, updated} <- update(board, op),
               true <-
                 byte_size(Jason.encode!(updated)) <=
                   Application.get_env(:nook, :board_max_bytes, 50_000_000) do
            {:ok, updated |> Map.update!("revision", &(&1 + 1)) |> remember_operation(op)}
          else
            false -> {:error, :limit}
            other -> other
          end
        end,
        if(op["type"] == "rename", do: :manage, else: :write)
      )

    case result do
      {:ok, {:changed, updated}} ->
        # Broadcast within the serialized operation so subscribers see revisions in order.
        NookWeb.Endpoint.broadcast("board:" <> code, "operation", %{
          "op" => canonical(op, updated),
          "revision" => updated["revision"]
        })

        {:reply, {:ok, updated["revision"]}, table}

      {:ok, {:duplicate, revision}} ->
        {:reply, {:ok, revision}, table}

      error ->
        {:reply, error, table}
    end
  end

  def handle_call({:manage, action, code, actor}, _, state) do
    result = apply(Nook.Boards.Store, action, [code, actor])

    if match?({:ok, _}, result) do
      NookWeb.Endpoint.broadcast("board:" <> code, "access_changed", %{})
    end

    {:reply, result, state}
  end

  defp operation_allowed(actor) do
    if Nook.RateLimit.allow?({:operation, actor.guest_id}, 240, 60_000),
      do: :ok,
      else: {:error, :rate_limited}
  end

  defp update(board, %{"type" => "rename", "title" => title})
       when is_binary(title) and byte_size(title) in 1..480,
       do: {:ok, Map.put(board, "title", title)}

  defp update(board, %{"type" => "batch", "ops" => ops}) do
    Enum.reduce_while(ops, {:ok, board}, fn op, {:ok, current} ->
      case update(current, op) do
        {:ok, next} -> {:cont, {:ok, next}}
        error -> {:halt, error}
      end
    end)
  end

  defp update(board, %{
         "type" => "put",
         "element" => %{"id" => id, "type" => type, "x" => x, "y" => y} = el
       })
       when is_binary(id) and byte_size(id) in 1..64 and type in @types and is_number(x) and
              is_number(y) do
    if map_size(board["elements"]) < 2000 and byte_size(Jason.encode!(el)) < 1_500_000 and
         valid_element?(el, board) and stroke_budget?(el, board) do
      {:ok, put_in(board, ["elements", id], el)}
    else
      {:error, :limit}
    end
  end

  defp update(board, %{"type" => "patch", "id" => id, "changes" => changes})
       when is_map(changes) do
    if valid_patch?(changes) do
      allowed =
        Map.take(
          changes,
          ~w(x y w h text color done shape font_size text_color description z items group_id auto_width icon locked from_anchor to_anchor points linear)
        )

      if Map.has_key?(board["elements"], id) do
        updated = Map.merge(board["elements"][id], allowed)

        if valid_element?(updated, board) and stroke_budget?(updated, board),
          do: {:ok, put_in(board, ["elements", id], updated)},
          else: {:error, :invalid}
      else
        # A collaborator may have deleted this element while the sender was offline.
        {:ok, board}
      end
    else
      {:error, :invalid}
    end
  end

  defp update(board, %{"type" => "delete", "id" => id}) do
    elements =
      Map.reject(board["elements"], fn {key, el} ->
        key == id or el["from"] == id or el["to"] == id
      end)

    {:ok, Map.put(board, "elements", elements)}
  end

  defp update(_, _), do: {:error, :invalid}

  defp check_version(board, %{"type" => "put", "element" => %{"id" => id}} = op) do
    current = board["elements"][id]

    if (is_nil(current) and op["replace"] != true) or
         (current && op["replace"] == true && op["base_revision"] == current["revision"]),
       do: :ok,
       else: {:error, {:conflict, board}}
  end

  defp check_version(board, %{"type" => "batch", "ops" => ops}) when is_list(ops) do
    ids =
      Enum.map(ops, fn
        %{"id" => id} -> id
        %{"element" => %{"id" => id}} -> id
        _ -> nil
      end)

    if length(ops) in 1..2000 and length(Enum.uniq(ids)) == length(ids) and
         Enum.all?(ops, &(is_map(&1) and &1["type"] in ~w(put patch delete))) and
         byte_size(Jason.encode!(ops)) < 1_500_000 do
      Enum.reduce_while(ops, :ok, fn op, :ok ->
        case check_version(board, op) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    else
      {:error, :invalid}
    end
  end

  defp check_version(_, %{"type" => "batch"}), do: {:error, :invalid}

  defp check_version(board, %{"type" => type, "id" => id} = op)
       when type in ["patch", "delete"] do
    current = board["elements"][id]
    changes = op["changes"]
    base = op["base"]

    cond do
      type == "patch" and (not is_map(changes) or not valid_patch?(changes)) ->
        {:error, :invalid}

      is_nil(current) ->
        {:error, {:conflict, board}}

      is_integer(op["base_revision"]) and op["base_revision"] == current["revision"] ->
        :ok

      type == "patch" and is_integer(op["base_revision"]) and op["base_revision"] > 0 and
        op["base_revision"] < current["revision"] and is_map(base) and
          Enum.all?(changes, fn {key, _} ->
            Map.has_key?(base, key) and base[key] == current[key]
          end) ->
        :ok

      true ->
        {:error, {:conflict, board}}
    end
  end

  defp check_version(_, _), do: :ok

  defp canonical(%{"type" => "put", "element" => el} = op, board),
    do: Map.take(op, ~w(type op_id)) |> Map.put("element", board["elements"][el["id"]])

  defp canonical(%{"type" => "batch", "ops" => ops} = op, board),
    do: Map.take(op, ~w(type op_id)) |> Map.put("ops", Enum.map(ops, &canonical(&1, board)))

  defp canonical(%{"type" => "patch", "id" => id} = op, board),
    do:
      Map.take(op, ~w(type op_id id changes))
      |> Map.put("element_revision", get_in(board, ["elements", id, "revision"]))

  defp canonical(op, _), do: Map.take(op, ~w(type op_id id title))

  defp valid_patch?(changes) do
    Enum.all?(changes, fn
      {k, v} when k in ~w(x y) -> is_number(v) and abs(v) < 10_000_000
      {k, v} when k in ~w(w h) -> is_number(v) and v >= 50 and v <= 10_000
      {"text", v} -> is_binary(v) and byte_size(v) <= 20_000
      {"color", v} -> v in ~w(lilac yellow peach mint white) or valid_hex?(v)
      {"icon", v} -> v in ~w(lightbulb arrow question warning checkmark person heart document)
      {"locked", v} -> is_boolean(v)
      {"linear", v} -> is_boolean(v)
      {"points", v} -> valid_points?(v)
      {"done", v} -> is_boolean(v)
      {"shape", v} -> v in ~w(rectangle rounded circle triangle diamond)
      {"font_size", v} -> is_integer(v) and v in 12..72
      {"text_color", v} -> v in ~w(purple charcoal violet white) or valid_hex?(v)
      {"description", v} -> is_binary(v) and byte_size(v) <= 8_000
      {"z", v} -> is_integer(v) and abs(v) <= 1_000_000
      {"group_id", v} -> is_nil(v) or (is_binary(v) and byte_size(v) in 1..64)
      {"auto_width", v} -> is_boolean(v)
      {"items", v} -> valid_items?(v)
      {k, v} when k in ~w(from_anchor to_anchor) -> valid_anchor?(v)
      _ -> false
    end)
  end

  defp valid_points?(points) when is_list(points) and length(points) in 1..2048 do
    Enum.all?(points, fn
      [x, y] -> is_number(x) and is_number(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1
      _ -> false
    end)
  end

  defp valid_points?(_), do: false

  defp valid_hex?(v), do: is_binary(v) and Regex.match?(~r/^#[0-9a-fA-F]{6}$/, v)

  defp valid_items?(items) when is_list(items) and length(items) <= 100 do
    ids = Enum.map(items, &if(is_map(&1), do: &1["id"]))

    length(Enum.uniq(ids)) == length(ids) and
      Enum.all?(items, fn
        %{"id" => id, "text" => text, "done" => done} = item ->
          map_size(item) == 3 and is_binary(id) and byte_size(id) in 1..64 and
            is_binary(text) and byte_size(text) <= 2000 and is_boolean(done)

        _ ->
          false
      end)
  end

  defp valid_items?(_), do: false
  defp valid_anchor?(nil), do: true

  defp valid_anchor?(%{"x" => x, "y" => y} = a),
    do:
      map_size(a) == 2 and is_number(x) and is_number(y) and x >= 0 and x <= 1 and y >= 0 and
        y <= 1

  defp valid_anchor?(_), do: false

  defp stroke_budget?(%{"type" => "stroke"} = el, board) do
    strokes =
      board["elements"]
      |> Map.values()
      |> Enum.filter(&(&1["type"] == "stroke" and &1["id"] != el["id"]))

    length(strokes) < 500 and
      length(el["points"]) + Enum.sum(Enum.map(strokes, &length(&1["points"]))) <= 100_000
  end

  defp stroke_budget?(_, _), do: true

  defp valid_element?(%{"type" => "stroke"} = el, _) do
    valid_patch?(Map.take(el, ~w(x y w h z locked group_id color linear))) and
      Enum.all?(~w(x y w h), &Map.has_key?(el, &1)) and
      valid_hex?(el["color"]) and is_integer(el["stroke_width"]) and el["stroke_width"] in 1..24 and
      is_list(el["points"]) and length(el["points"]) in 1..2048 and
      Enum.all?(el["points"], fn
        [x, y] -> is_number(x) and is_number(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1
        _ -> false
      end)
  end

  defp valid_element?(%{"type" => "connection", "from" => from, "to" => to} = el, board) do
    valid_patch?(Map.take(el, ~w(group_id from_anchor to_anchor))) and from != to and
      Enum.all?([from, to], fn id ->
        case board["elements"][id] do
          %{"type" => type} -> type != "connection"
          _ -> false
        end
      end)
  end

  defp valid_element?(%{"type" => "connection"}, _), do: false

  defp valid_element?(el, _) do
    geometry = Map.take(el, ~w(x y w h))

    map_size(geometry) == 4 and valid_patch?(geometry) and
      valid_patch?(
        Map.take(
          el,
          ~w(text color done shape font_size text_color description z items group_id auto_width icon locked)
        )
      ) and
      if el["type"] == "file" and Map.has_key?(el, "data"),
        do: valid_file?(el),
        else:
          is_binary(el["text"]) and
            (el["type"] != "icon" or
               el["icon"] in ~w(lightbulb arrow question warning checkmark person heart document))
  end

  defp valid_file?(%{"name" => name, "mime" => mime, "data" => data})
       when is_binary(name) and byte_size(name) <= 255 and is_binary(data) do
    mime in [
      "image/png",
      "image/jpeg",
      "image/gif",
      "image/webp",
      "application/pdf",
      "text/plain",
      "text/csv",
      "text/markdown",
      ""
    ] and
      Regex.match?(
        ~r/^data:(image\/(png|jpeg|gif|webp)|application\/pdf|text\/(plain|csv|markdown)|application\/octet-stream);base64,[A-Za-z0-9+\/=]+$/,
        data
      )
  end

  defp valid_file?(_), do: false

  defp check_replay(board, %{"op_id" => id}) when is_binary(id) and byte_size(id) <= 64 do
    if id in Map.get(board, "recent_operations", []),
      do: {:duplicate, board["revision"]},
      else: :new
  end

  defp check_replay(_, %{"op_id" => _}), do: {:error, :invalid}
  defp check_replay(_, _), do: :new

  defp remember_operation(board, %{"op_id" => id}) do
    Map.put(
      board,
      "recent_operations",
      Enum.take([id | Map.get(board, "recent_operations", [])], 512)
    )
  end

  defp remember_operation(board, _), do: board
end
