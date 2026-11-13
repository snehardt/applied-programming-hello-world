defmodule Nook.RateLimitTest do
  use ExUnit.Case, async: true

  test "a window rejects excess writes and resets independently" do
    {:ok, pid} = GenServer.start_link(Nook.RateLimit, %{})
    assert GenServer.call(pid, {:allow, :first, 1, 20})
    refute GenServer.call(pid, {:allow, :first, 1, 20})
    assert GenServer.call(pid, {:allow, :other, 1, 20})
    Process.sleep(30)
    assert GenServer.call(pid, {:allow, :first, 1, 20})
  end
end
