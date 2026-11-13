defmodule Nook.MultiplayerTest do
  use Nook.DataCase, async: false
  alias Nook.{Access, Boards, Rooms, Repo}

  defp note,
    do: %{
      "id" => "a",
      "type" => "note",
      "x" => 10,
      "y" => 20,
      "w" => 230,
      "h" => 200,
      "text" => "Original",
      "color" => "lilac"
    }

  defp patch(rev, changes, base \\ %{}),
    do: %{
      "type" => "patch",
      "id" => "a",
      "base_revision" => rev,
      "base" => base,
      "changes" => changes
    }

  test "room requests reveal no content, need current owner approval, and cannot be stolen" do
    owner = Access.new_guest()
    guest = Access.new_guest()
    other = Access.new_guest()
    code = Boards.create(owner)["code"]
    assert {:error, _} = Rooms.request(code, guest, "Sam")
    assert {:error, _} = Rooms.set_open(code, other, true)
    assert {:ok, _} = Rooms.set_open(code, owner, true)
    assert {:ok, request} = Rooms.request(code, guest, "Sam")
    assert Map.keys(request) |> Enum.sort() == [:id, :name, :status]
    assert {:ok, ^request} = Rooms.request(code, guest, "Duplicate")
    assert {:error, _} = Rooms.status(request.id, other)
    assert {:error, _} = Rooms.list(code, guest)
    assert {:error, _} = Rooms.decide(code, request.id, other, "approved")
    assert {:error, :not_found} = Boards.get(code, guest)
    assert {:ok, [^request]} = Rooms.list(code, owner)
    assert {:ok, _} = Rooms.decide(code, request.id, owner, "approved")
    assert {:ok, %{status: "approved", path: path}} = Rooms.status(request.id, guest)
    assert path == "/b/#{code}"
    assert {:ok, %{"can_manage" => false}} = Boards.get(code, guest)
    assert {:error, :not_found} = Boards.manage(:issue_invite, code, guest)
    Rooms.set_open(code, owner, false)
    assert {:ok, _} = Boards.get(code, guest)
    Boards.manage(:disable_sharing, code, owner)
    assert {:error, :not_found} = Boards.get(code, guest)
    assert {:ok, %{status: "expired"}} = Rooms.status(request.id, guest)
  end

  test "expired, declined, and old-epoch requests cannot admit visitors" do
    owner = Access.new_guest()
    guest = Access.new_guest()
    code = Boards.create(owner)["code"]
    Rooms.set_open(code, owner, true)
    {:ok, request} = Rooms.request(code, guest, "Visitor")
    r = Repo.get!(Nook.Rooms.Request, request.id)
    r |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -1)) |> Repo.update!()
    assert {:error, _} = Rooms.decide(code, request.id, owner, "approved")
    {:ok, next} = Rooms.request(code, guest, "Visitor")
    assert next.id != request.id
    Rooms.decide(code, next.id, owner, "denied")
    assert {:ok, %{status: "denied"}} = Rooms.status(next.id, guest)
    assert {:error, _} = Rooms.decide(code, next.id, owner, "approved")
    Boards.manage(:issue_invite, code, owner)
    assert {:ok, %{status: "expired"}} = Rooms.status(next.id, guest)
  end

  test "stale independent fields merge, competing edits and stale deletes preserve data" do
    actor = Access.new_guest()
    code = Boards.create(actor)["code"]
    assert {:ok, 1} = Boards.apply_op(code, %{"type" => "put", "element" => note()}, actor)
    assert {:ok, 2} = Boards.apply_op(code, patch(1, %{"text" => "Alice"}), actor)
    assert {:ok, 3} = Boards.apply_op(code, patch(1, %{"x" => 80}, %{"x" => 10}), actor)

    assert {:error, {:conflict, snapshot}} =
             Boards.apply_op(code, patch(1, %{"text" => "Bob"}, %{"text" => "Original"}), actor)

    assert snapshot["elements"]["a"]["text"] == "Alice"
    assert snapshot["elements"]["a"]["revision"] == 3

    assert {:error, {:conflict, _}} =
             Boards.apply_op(
               code,
               %{"type" => "delete", "id" => "a", "base_revision" => 1},
               actor
             )

    assert {:error, {:conflict, _}} = Boards.apply_op(code, patch(nil, %{"x" => 90}), actor)

    assert {:error, {:conflict, _}} =
             Boards.apply_op(code, %{"type" => "put", "element" => note()}, actor)

    assert {:ok, 4} =
             Boards.apply_op(
               code,
               %{"type" => "delete", "id" => "a", "base_revision" => 3},
               actor
             )

    assert {:error, {:conflict, _}} =
             Boards.apply_op(
               code,
               %{"type" => "put", "element" => note(), "replace" => true, "base_revision" => 3},
               actor
             )

    assert {:error, {:conflict, _}} =
             Boards.apply_op(code, patch(3, %{"text" => "Zombie"}), actor)
  end

  test "a lost acknowledgement replay is deduplicated before revision validation" do
    actor = Access.new_guest()
    code = Boards.create(actor)["code"]
    Boards.apply_op(code, %{"type" => "put", "element" => note()}, actor)
    op = Map.put(patch(1, %{"text" => "Once"}), "op_id", "deduplicated")
    assert {:ok, 2} = Boards.apply_op(code, op, actor)
    assert {:ok, 3} = Boards.apply_op(code, patch(2, %{"text" => "Newer"}), actor)
    assert {:ok, 3} = Boards.apply_op(code, op, actor)
    {:ok, snapshot} = Boards.get(code, actor)
    assert snapshot["elements"]["a"]["text"] == "Newer"
  end
end
