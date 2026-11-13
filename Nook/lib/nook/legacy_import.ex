defmodule Nook.LegacyImport do
  @moduledoc "Read-only, repeatable import of Milestone 1 DETS data. The source is retained."
  def run(path) do
    if File.exists?(path) do
      with {:ok, table} <-
             :dets.open_file(:nook_legacy_import,
               file: String.to_charlist(path),
               access: :read,
               repair: false
             ) do
        try do
          :dets.foldl(
            fn {_code, board}, counts ->
              case Nook.Boards.Store.import_snapshot(board) do
                {:ok, result} -> Map.update!(counts, result, &(&1 + 1))
                {:error, reason} -> raise "Legacy import failed: #{inspect(reason)}"
              end
            end,
            %{imported: 0, skipped: 0},
            table
          )
        after
          :dets.close(table)
        end
      end
    else
      %{imported: 0, skipped: 0}
    end
  end
end
