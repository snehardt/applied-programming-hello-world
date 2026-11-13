defmodule Nook.GuestExpiry do
  use GenServer
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    Process.send_after(self(), :expire, interval())
    {:ok, nil}
  end

  defp interval, do: Application.get_env(:nook, :expiry_interval_ms, 60_000)

  def handle_info(:expire, state) do
    case Nook.Boards.Store.expire_due() do
      {:ok, codes} ->
        Enum.each(codes, &NookWeb.Endpoint.broadcast("board:" <> &1, "access_changed", %{}))

      _ ->
        :ok
    end

    Process.send_after(self(), :expire, interval())
    {:noreply, state}
  end
end
