defmodule Nook.LongStrokesTest do
  use NookWeb.ConnCase, async: false

  defp stroke(id, points) do
    %{
      "id" => id,
      "type" => "stroke",
      "x" => 0,
      "y" => 0,
      "w" => 200,
      "h" => 200,
      "color" => "#210a3b",
      "stroke_width" => 4,
      "linear" => true,
      "points" => points
    }
  end

  test "a complete 100,000 point stroke persists and rotates as one element" do
    actor = Nook.Access.new_guest()
    code = Nook.Boards.create(actor)["code"]
    points = List.duplicate([0.12345678912345678, 0.9876543219876543], 100_000)
    el = stroke("long", points)
    # Exercise the real JSON round trip; this exceeds the old frame/element limits.
    op = Jason.decode!(Jason.encode!(%{"type" => "put", "element" => el}))
    assert {:ok, 1} = Nook.Boards.apply_op(code, op, actor)

    assert {:ok, 2} =
             Nook.Boards.apply_op(
               code,
               %{
                 "type" => "patch",
                 "id" => "long",
                 "base_revision" => 1,
                 "changes" => %{"rotation" => 810, "x" => 300}
               },
               actor
             )

    assert {:ok, board} = Nook.Boards.get(code, actor)
    assert map_size(board["elements"]) == 1
    assert board["elements"]["long"]["points"] == points
    assert board["elements"]["long"]["rotation"] == 810

    assert {:error, :limit} =
             Nook.Boards.apply_op(
               code,
               %{"type" => "put", "element" => stroke("extra", [[0, 0]])},
               actor
             )

    assert {:ok, 3} =
             Nook.Boards.apply_op(
               code,
               %{"type" => "delete", "id" => "long", "base_revision" => 2},
               actor
             )

    assert {:ok, 4} = Nook.Boards.apply_op(code, op, actor)
    assert {:ok, restored} = Nook.Boards.get(code, actor)
    assert restored["elements"]["long"]["points"] == points
  end

  test "more than 500 simple strokes fit within the shared point allowance" do
    actor = Nook.Access.new_guest()
    code = Nook.Boards.create(actor)["code"]
    ops = for i <- 1..501, do: %{"type" => "put", "element" => stroke("s#{i}", [[0, 0], [1, 1]])}
    assert {:ok, 1} = Nook.Boards.apply_op(code, %{"type" => "batch", "ops" => ops}, actor)
    assert {:ok, board} = Nook.Boards.get(code, actor)
    assert map_size(board["elements"]) == 501
  end
end
