defmodule Nook.LaunchLimitsTest do
  use Nook.DataCase, async: false

  setup do
    old = Application.get_env(:nook, :launch_limits)
    bytes = Application.get_env(:nook, :board_max_bytes)
    Application.put_env(:nook, :launch_limits, true)

    on_exit(fn ->
      if is_nil(old),
        do: Application.delete_env(:nook, :launch_limits),
        else: Application.put_env(:nook, :launch_limits, old)

      if is_nil(bytes),
        do: Application.delete_env(:nook, :board_max_bytes),
        else: Application.put_env(:nook, :board_max_bytes, bytes)
    end)

    :ok
  end

  test "board creation is bounded for each visitor" do
    actor = Nook.Access.new_guest()
    for _ <- 1..20, do: assert(%{"code" => _} = Nook.Boards.create(actor))
    assert {:error, :rate_limited} = Nook.Boards.create(actor)
    assert %{"code" => _} = Nook.Boards.create(Nook.Access.new_guest())
  end

  test "aggregate board size rejects the write without altering saved content" do
    actor = Nook.Access.new_guest()
    board = Nook.Boards.create(actor)
    Application.put_env(:nook, :board_max_bytes, 1000)

    element = %{
      "id" => "large",
      "type" => "note",
      "x" => 0,
      "y" => 0,
      "w" => 200,
      "h" => 200,
      "text" => String.duplicate("x", 2000)
    }

    assert {:error, :limit} =
             Nook.Boards.apply_op(board["code"], %{"type" => "put", "element" => element}, actor)

    assert {:ok, saved} = Nook.Boards.get(board["code"], actor)
    assert saved["elements"] == %{}
    assert saved["revision"] == 0
  end
end
