# Read-only acceptance check for the one-time Milestone 1 migration.
path = "data/boards.dets"
if File.exists?(path) do
  {:ok, table} = :dets.open_file(:nook_legacy_verify, file: String.to_charlist(path), access: :read, repair: false)
  try do
    count = :dets.foldl(fn {code, original}, count ->
      {:ok, saved} = Nook.Boards.Store.get(code)
      for {id, element} <- original["elements"] do
        persisted = Map.fetch!(saved["elements"], id)
        unless Map.take(persisted, Map.keys(element)) == element do
          raise "Legacy element differs after import in board #{code}"
        end
      end
      unless saved["title"] == original["title"], do: raise("Legacy title differs in #{code}")
      count + 1
    end, 0, table)
    IO.puts("PASS: #{count} legacy boards retain every original element field and title in PostgreSQL")
  after
    :dets.close(table)
  end
end
