defmodule Nook.AdvancedCanvasTest do
  use Nook.DataCase, async: false
  alias Nook.{Access, Boards}

  defp note(id),
    do: %{
      "id" => id,
      "type" => "note",
      "x" => 10,
      "y" => 20,
      "w" => 230,
      "h" => 200,
      "text" => "Original"
    }

  defp patch(id, rev, changes),
    do: %{"type" => "patch", "id" => id, "base_revision" => rev, "changes" => changes}

  defp batch(ops), do: %{"type" => "batch", "ops" => ops, "op_id" => Access.secret()}

  test "malformed operation envelopes cannot crash the board coordinator" do
    actor = Access.new_guest()
    code = Boards.create(actor)["code"]
    coordinator = Process.whereis(Boards)

    for operation <- [
          nil,
          [],
          "bad",
          batch([%{"type" => "put", "element" => "bad"}]),
          batch([42]),
          %{"type" => "batch", "ops" => "bad"}
        ] do
      assert {:error, :invalid} = Boards.apply_op(code, operation, actor)
      assert Process.whereis(Boards) == coordinator
    end

    assert {:ok, 1} =
             Boards.apply_op(code, %{"type" => "put", "element" => note("still-works")}, actor)
  end

  test "multi-object move and grouping commit once with canonical element revisions" do
    actor = Access.new_guest()
    code = Boards.create(actor)["code"]

    assert {:ok, 1} =
             Boards.apply_op(
               code,
               batch(for id <- ~w(a b), do: %{"type" => "put", "element" => note(id)}),
               actor
             )

    assert {:ok, 2} =
             Boards.apply_op(
               code,
               batch(
                 for id <- ~w(a b), do: patch(id, 1, %{"x" => 90, "group_id" => "group-one"})
               ),
               actor
             )

    {:ok, board} = Boards.get(code, actor)
    assert board["revision"] == 2

    for id <- ~w(a b) do
      assert board["elements"][id]["x"] == 90
      assert board["elements"][id]["revision"] == 2
      assert board["elements"][id]["group_id"] == "group-one"
    end

    assert {:ok, 3} =
             Boards.apply_op(
               code,
               batch(for id <- ~w(a b), do: patch(id, 2, %{"group_id" => nil})),
               actor
             )

    {:ok, board} = Boards.get(code, actor)
    assert is_nil(board["elements"]["a"]["group_id"])
  end

  test "a conflict or invalid child rolls back the entire selection and replay does not repeat it" do
    actor = Access.new_guest()
    code = Boards.create(actor)["code"]

    Boards.apply_op(
      code,
      batch(for id <- ~w(a b), do: %{"type" => "put", "element" => note(id)}),
      actor
    )

    Boards.apply_op(code, patch("b", 1, %{"x" => 50}), actor)

    assert {:error, {:conflict, _}} =
             Boards.apply_op(
               code,
               batch([patch("a", 1, %{"x" => 200}), patch("b", 1, %{"x" => 200})]),
               actor
             )

    {:ok, board} = Boards.get(code, actor)
    assert board["elements"]["a"]["x"] == 10
    assert board["revision"] == 2

    assert {:error, :invalid} =
             Boards.apply_op(
               code,
               batch([patch("a", 1, %{"x" => 200}), patch("b", 2, %{"font_size" => 500})]),
               actor
             )

    operation = batch([patch("a", 1, %{"x" => 100}), patch("b", 2, %{"x" => 100})])
    assert {:ok, 3} = Boards.apply_op(code, operation, actor)
    assert {:ok, 3} = Boards.apply_op(code, operation, actor)
  end

  test "checklists, font sizes, anchors, groups and legacy task content survive fresh reads" do
    actor = Access.new_guest()
    code = Boards.create(actor)["code"]

    legacy =
      Map.merge(note("old"), %{
        "type" => "task",
        "text" => "Existing task",
        "done" => true,
        "description" => "Keep this"
      })

    items = [
      %{"id" => "one", "text" => "Sketch", "done" => true},
      %{"id" => "two", "text" => "Build", "done" => false}
    ]

    task =
      Map.merge(note("new"), %{
        "type" => "task",
        "text" => "Project",
        "items" => items,
        "font_size" => 32
      })

    edge = %{
      "id" => "edge",
      "type" => "connection",
      "x" => 0,
      "y" => 0,
      "from" => "old",
      "to" => "new",
      "from_anchor" => %{"x" => 0.5, "y" => 1}
    }

    assert {:ok, 1} =
             Boards.apply_op(
               code,
               batch(for el <- [legacy, task, edge], do: %{"type" => "put", "element" => el}),
               actor
             )

    assert {:ok, 2} =
             Boards.apply_op(
               code,
               patch("new", 1, %{"items" => Enum.reverse(items), "auto_width" => false}),
               actor
             )

    {:ok, board} = Boards.Store.get(code)
    assert board["elements"]["old"]["done"]
    assert board["elements"]["old"]["text"] == "Existing task"
    assert board["elements"]["new"]["items"] == Enum.reverse(items)
    assert board["elements"]["new"]["font_size"] == 32
    assert board["elements"]["edge"]["from_anchor"] == %{"x" => 0.5, "y" => 1}

    assert {:ok, 3} =
             Boards.apply_op(
               code,
               batch([
                 %{"type" => "delete", "id" => "old", "base_revision" => 1},
                 %{"type" => "delete", "id" => "new", "base_revision" => 2}
               ]),
               actor
             )

    {:ok, empty} = Boards.get(code, actor)
    assert empty["elements"] == %{}
  end

  test "malformed lists and anchors, nested batches and metadata privilege escalation are rejected" do
    actor = Access.new_guest()
    code = Boards.create(actor)["code"]
    Boards.apply_op(code, %{"type" => "put", "element" => note("a")}, actor)

    bad = [
      %{"items" => [%{"id" => "a", "text" => "Unsafe", "done" => "yes"}]},
      %{"items" => List.duplicate(%{"id" => "a", "text" => "Dup", "done" => false}, 2)},
      %{"from_anchor" => %{"x" => 2, "y" => 0}},
      %{"group_id" => 5}
    ]

    for changes <- bad,
        do: assert({:error, :invalid} = Boards.apply_op(code, patch("a", 1, changes), actor))

    assert {:error, :invalid} =
             Boards.apply_op(code, batch([batch([patch("a", 1, %{"x" => 2})])]), actor)

    assert {:error, :invalid} =
             Boards.apply_op(
               code,
               batch([%{"type" => "rename", "title" => "Bypass owner"}]),
               actor
             )

    assert {:error, :invalid} =
             Boards.apply_op(
               code,
               batch([patch("a", 1, %{"x" => 2}), patch("a", 1, %{"y" => 3})]),
               actor
             )
  end
end
