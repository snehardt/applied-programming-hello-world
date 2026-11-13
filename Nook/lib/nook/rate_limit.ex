defmodule Nook.RateLimit do
  @moduledoc "Small in-memory, bounded launch limits. No user content is stored here."
  use GenServer
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def allow?(key, limit, window_ms) do
    if Application.get_env(:nook, :launch_limits, false),
      do: GenServer.call(__MODULE__, {:allow, key, limit, window_ms}),
      else: true
  end

  def init(state) do
    Process.send_after(self(), :cleanup, 60_000)
    {:ok, state}
  end

  def handle_call({:allow, key, limit, window}, _, state) do
    now = System.monotonic_time(:millisecond)
    {count, until} = Map.get(state, key, {0, now + window})
    {count, until} = if until <= now, do: {0, now + window}, else: {count, until}

    if count < limit and (Map.has_key?(state, key) or map_size(state) < 20_000),
      do: {:reply, true, Map.put(state, key, {count + 1, until})},
      else: {:reply, false, state}
  end

  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    Process.send_after(self(), :cleanup, 60_000)
    {:noreply, Map.reject(state, fn {_, {_, until}} -> until <= now end)}
  end
end
