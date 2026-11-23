defmodule Nook.BoardsTest do
  use ExUnit.Case, async: false
  import Ecto.Query

  setup do
    Process.put(:board_actor, Nook.Access.new_guest())
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Nook.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Nook.Repo, {:shared, self()})
    :ok
  end

  defp actor, do: Process.get(:board_actor)

  defp note(id) do
    %{
      "id" => id,
      "type" => "note",
      "x" => 10,
      "y" => 20,
      "w" => 230,
      "h" => 200,
      "text" => "Hello",
      "color" => "lilac"
    }
  end

  test "stroke cleanup patches persist and undo restores rough geometry without deleting the stroke" do
    code = Nook.Boards.create(actor())["code"]

    rough = %{
      "id" => "rough",
      "type" => "stroke",
      "x" => 0,
      "y" => 0,
      "w" => 100,
      "h" => 50,
      "text" => "",
      "color" => "#210a3b",
      "stroke_width" => 4,
      "linear" => false,
      "points" => [[0, 0], [0.5, 0.2], [1, 0]]
    }

    assert {:ok, 1} = Nook.Boards.apply_op(code, %{"type" => "put", "element" => rough}, actor())

    assert {:ok, 2} =
             Nook.Boards.apply_op(
               code,
               %{
                 "type" => "patch",
                 "id" => "rough",
                 "base_revision" => 1,
                 "changes" => %{"points" => [[0, 0], [1, 0]], "linear" => true}
               },
               actor()
             )

    {:ok, clean} = Nook.Boards.get(code, actor())
    assert clean["elements"]["rough"]["linear"]

    assert {:error, :invalid} =
             Nook.Boards.apply_op(
               code,
               %{
                 "type" => "patch",
                 "id" => "rough",
                 "base_revision" => 2,
                 "changes" => %{"points" => [[2, 0]]}
               },
               actor()
             )

    assert {:ok, 3} =
             Nook.Boards.apply_op(
               code,
               %{
                 "type" => "patch",
                 "id" => "rough",
                 "base_revision" => 2,
                 "changes" => Map.take(rough, ~w(points linear))
               },
               actor()
             )

    {:ok, restored} = Nook.Boards.get(code, actor())
    assert restored["elements"]["rough"]["points"] == rough["points"]
    refute restored["elements"]["rough"]["linear"]
  end

  test "drawing budgets reject excess points atomically and retain existing content" do
    code = Nook.Boards.create(actor())["code"]

    stroke = %{
      "type" => "stroke",
      "x" => 0,
      "y" => 0,
      "w" => 50,
      "h" => 50,
      "text" => "",
      "color" => "#210a3b",
      "stroke_width" => 4
    }

    ops =
      for i <- 1..49,
          do: %{
            "type" => "put",
            "element" =>
              Map.merge(stroke, %{
                "id" => "s#{i}",
                "points" => List.duplicate([0, 0], if(i == 49, do: 1696, else: 2048))
              })
          }

    assert {:ok, 1} = Nook.Boards.apply_op(code, %{"type" => "batch", "ops" => ops}, actor())
    extra = Map.merge(stroke, %{"id" => "excess", "points" => [[0, 0]]})

    assert {:error, :limit} =
             Nook.Boards.apply_op(code, %{"type" => "put", "element" => extra}, actor())

    {:ok, board} = Nook.Boards.get(code, actor())
    assert map_size(board["elements"]) == 49
    assert board["revision"] == 1
  end

  test "drawing strokes persist, move and reject unsafe or oversized geometry" do
    code = Nook.Boards.create(actor())["code"]

    stroke = %{
      "id" => "ink",
      "type" => "stroke",
      "x" => -10,
      "y" => 20,
      "w" => 80,
      "h" => 50,
      "text" => "",
      "color" => "#AD7BFA",
      "stroke_width" => 4,
      "points" => [[0.1, 0.2], [0.8, 0.7]]
    }

    assert {:ok, 1} = Nook.Boards.apply_op(code, %{"type" => "put", "element" => stroke}, actor())
    assert {:ok, board} = Nook.Boards.get(code, actor())
    assert board["elements"]["ink"]["points"] == stroke["points"]

    assert {:ok, 2} =
             Nook.Boards.apply_op(
               code,
               %{
                 "type" => "patch",
                 "id" => "ink",
                 "base_revision" => 1,
                 "changes" => %{"x" => 100}
               },
               actor()
             )

    for change <- [
          %{"points" => []},
          %{"points" => [[2, 0]]},
          %{"points" => List.duplicate([0, 0], 100_001)},
          %{"stroke_width" => 0},
          %{"color" => "url(evil)"}
        ] do
      assert {:error, _} =
               Nook.Boards.apply_op(
                 code,
                 %{
                   "type" => "put",
                   "element" => Map.merge(stroke, change) |> Map.put("id", "invalid")
                 },
                 actor()
               )
    end

    assert {:ok, current} = Nook.Boards.get(code, actor())
    assert current["elements"]["ink"]["x"] == 100
    assert current["elements"]["ink"]["points"] == stroke["points"]
  end

  test "boards stay isolated, and connections are removed with their endpoint" do
    a = Nook.Boards.create(actor())
    b = Nook.Boards.create(actor())

    assert {:ok, 1} =
             Nook.Boards.apply_op(a["code"], %{"type" => "put", "element" => note("a")}, actor())

    assert {:ok, 2} =
             Nook.Boards.apply_op(a["code"], %{"type" => "put", "element" => note("b")}, actor())

    connection = %{
      "id" => "edge",
      "type" => "connection",
      "x" => 0,
      "y" => 0,
      "from" => "a",
      "to" => "b"
    }

    assert {:ok, 3} =
             Nook.Boards.apply_op(a["code"], %{"type" => "put", "element" => connection}, actor())

    assert {:ok, 4} =
             Nook.Boards.apply_op(
               a["code"],
               %{"type" => "delete", "id" => "a", "base_revision" => 1},
               actor()
             )

    {:ok, result} = Nook.Boards.get(a["code"], actor())
    assert Map.keys(result["elements"]) == ["b"]
    {:ok, other} = Nook.Boards.get(b["code"], actor())
    assert other["elements"] == %{}
  end

  test "independent patches preserve concurrent changes" do
    board = Nook.Boards.create(actor())
    code = board["code"]
    Nook.Boards.apply_op(code, %{"type" => "put", "element" => note("a")}, actor())

    Nook.Boards.apply_op(
      code,
      %{"type" => "patch", "id" => "a", "base_revision" => 1, "changes" => %{"text" => "Edited"}},
      actor()
    )

    Nook.Boards.apply_op(
      code,
      %{
        "type" => "patch",
        "id" => "a",
        "base_revision" => 1,
        "base" => %{"x" => 10},
        "changes" => %{"x" => -150}
      },
      actor()
    )

    {:ok, result} = Nook.Boards.get(code, actor())
    assert result["elements"]["a"]["text"] == "Edited"
    assert result["elements"]["a"]["x"] == -150
    persisted = Nook.Repo.get_by!(Nook.Boards.Element, board_code: code, id: "a")
    assert persisted.x == -150.0
    assert persisted.content["text"] == "Edited"
    assert persisted.revision == 3
  end

  test "replayed operations do not overwrite newer collaborator edits" do
    code = Nook.Boards.create(actor())["code"]
    op = %{"type" => "put", "element" => note("a"), "op_id" => "once-only"}
    assert {:ok, 1} = Nook.Boards.apply_op(code, op, actor())

    assert {:ok, 2} =
             Nook.Boards.apply_op(
               code,
               %{
                 "type" => "patch",
                 "id" => "a",
                 "base_revision" => 1,
                 "changes" => %{"text" => "A newer edit"}
               },
               actor()
             )

    assert {:ok, 2} = Nook.Boards.apply_op(code, op, actor())
    {:ok, board} = Nook.Boards.get(code, actor())
    assert board["elements"]["a"]["text"] == "A newer edit"

    assert {:ok, 3} =
             Nook.Boards.apply_op(
               code,
               %{"type" => "delete", "id" => "a", "base_revision" => 2},
               actor()
             )

    assert {:error, {:conflict, _}} =
             Nook.Boards.apply_op(
               code,
               %{"type" => "patch", "id" => "a", "base_revision" => 2, "changes" => %{"x" => 42}},
               actor()
             )

    {:ok, board} = Nook.Boards.get(code, actor())
    assert board["elements"] == %{}
  end

  test "malformed geometry, unsafe files, unknown rooms and dangling edges are rejected" do
    code = Nook.Boards.create(actor())["code"]

    invalid = [
      Map.delete(note("a"), "w"),
      Map.put(note("a"), "w", -5),
      %{"id" => "bad", "type" => "connection", "x" => 0, "y" => 0, "from" => "x", "to" => "y"},
      Map.merge(note("a"), %{
        "type" => "file",
        "name" => "bad",
        "mime" => "text/plain",
        "data" => "javascript:alert(1)"
      })
    ]

    for el <- invalid do
      assert {:error, _} =
               Nook.Boards.apply_op(code, %{"type" => "put", "element" => el}, actor())
    end

    assert {:error, :not_found} = Nook.Boards.get("UNKNOWN", actor())

    assert {:ok, _} =
             Nook.Boards.apply_op(code, %{"type" => "put", "element" => note("valid")}, actor())

    assert {:error, :invalid} =
             Nook.Boards.apply_op(
               code,
               %{"type" => "patch", "id" => "valid", "changes" => %{"w" => "oops"}},
               actor()
             )
  end

  test "all basic shapes, text styling, descriptions and layers survive a fresh database read" do
    code = Nook.Boards.create(actor())["code"]

    for shape <- ~w(rectangle rounded circle triangle diamond) do
      el = Map.merge(note(shape), %{"type" => "shape", "shape" => shape})
      assert {:ok, _} = Nook.Boards.apply_op(code, %{"type" => "put", "element" => el}, actor())
    end

    task =
      Map.merge(note("task"), %{
        "type" => "task",
        "done" => true,
        "description" => "Build a Rocket League training plan",
        "z" => 5
      })

    text =
      Map.merge(note("text"), %{"type" => "text", "font_size" => 48, "text_color" => "violet"})

    for el <- [task, text] do
      assert {:ok, _} = Nook.Boards.apply_op(code, %{"type" => "put", "element" => el}, actor())
    end

    {:ok, snapshot} = Nook.Boards.Store.get(code)
    assert map_size(snapshot["elements"]) == 7
    assert snapshot["elements"]["diamond"]["shape"] == "diamond"
    assert snapshot["elements"]["task"]["description"] == task["description"]
    assert snapshot["elements"]["task"]["z"] == 5
    assert snapshot["elements"]["text"]["font_size"] == 48
    assert snapshot["elements"]["text"]["text_color"] == "violet"

    for changes <- [
          %{"shape" => "script"},
          %{"font_size" => 900},
          %{"z" => 1.5},
          %{"text_color" => "url(evil)"}
        ] do
      assert {:error, :invalid} =
               Nook.Boards.apply_op(
                 code,
                 %{"type" => "patch", "id" => "text", "changes" => changes},
                 actor()
               )
    end
  end

  test "legacy import preserves codes and connections, and reruns never overwrite newer work" do
    code = "LEGACYBOARD01"

    board = %{
      "code" => code,
      "title" => "Old Nook board",
      "revision" => 2,
      "elements" => %{
        "a" => note("a"),
        "b" => note("b"),
        "edge" => %{
          "id" => "edge",
          "type" => "connection",
          "x" => 0,
          "y" => 0,
          "from" => "a",
          "to" => "b"
        }
      }
    }

    assert {:ok, :imported} = Nook.Boards.Store.import_snapshot(board)
    token = Nook.Access.secret()

    Nook.Repo.get!(Nook.Boards.Board, code)
    |> Ecto.Changeset.change(recovery_hash: Nook.Access.hash(token))
    |> Nook.Repo.update!()

    assert {:ok, :ok} = Nook.Boards.Store.redeem(code, token, actor(), :recovery)

    assert {:ok, 3} =
             Nook.Boards.apply_op(code, %{"type" => "rename", "title" => "Newer title"}, actor())

    assert {:ok, :skipped} = Nook.Boards.Store.import_snapshot(board)
    {:ok, result} = Nook.Boards.get(code, actor())
    assert result["title"] == "Newer title"
    assert result["elements"]["a"]["text"] == "Hello"
    assert result["elements"]["edge"]["to"] == "b"
  end

  test "failed operations leave both board revisions and element records untouched" do
    code = Nook.Boards.create(actor())["code"]

    assert {:ok, 1} =
             Nook.Boards.apply_op(code, %{"type" => "put", "element" => note("a")}, actor())

    assert {:error, :invalid} =
             Nook.Boards.apply_op(
               code,
               %{"type" => "patch", "id" => "a", "changes" => %{"x" => "NaN"}},
               actor()
             )

    assert Nook.Repo.get!(Nook.Boards.Board, code).revision == 1

    assert Nook.Repo.one(
             from(e in Nook.Boards.Element, where: e.board_code == ^code, select: e.x)
           ) == 10.0
  end

  test "icons, custom colors and position locks persist with validated values" do
    board = Nook.Boards.create(actor())

    icon =
      Map.merge(note("symbol"), %{
        "type" => "icon",
        "icon" => "heart",
        "color" => "#AD7BFA",
        "text_color" => "#210a3b",
        "locked" => true
      })

    assert {:ok, 1} =
             Nook.Boards.apply_op(board["code"], %{"type" => "put", "element" => icon}, actor())

    for changes <- [
          %{"icon" => "<script>"},
          %{"color" => "url(evil)"},
          %{"locked" => "yes"},
          %{"text_color" => "#fff"}
        ] do
      assert {:error, _} =
               Nook.Boards.apply_op(
                 board["code"],
                 %{
                   "type" => "patch",
                   "id" => "symbol",
                   "base_revision" => 1,
                   "changes" => changes
                 },
                 actor()
               )
    end

    assert {:ok, 2} =
             Nook.Boards.apply_op(
               board["code"],
               %{
                 "type" => "patch",
                 "id" => "symbol",
                 "base_revision" => 1,
                 "changes" => %{"locked" => false, "icon" => "document", "color" => "#123456"}
               },
               actor()
             )

    assert {:ok, saved} = Nook.Boards.get(board["code"], actor())
    assert saved["elements"]["symbol"]["icon"] == "document"
    assert saved["elements"]["symbol"]["locked"] == false
    assert saved["elements"]["symbol"]["color"] == "#123456"
  end
end
