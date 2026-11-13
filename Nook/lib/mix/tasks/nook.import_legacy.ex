defmodule Mix.Tasks.Nook.ImportLegacy do
  use Mix.Task
  @shortdoc "Import existing DETS boards into PostgreSQL without overwriting saved boards"
  def run(args) do
    Mix.Task.run("app.start")
    path = List.first(args) || "data/boards.dets"

    case Nook.LegacyImport.run(path) do
      %{imported: imported, skipped: skipped} ->
        Mix.shell().info(
          "Legacy boards: #{imported} imported, #{skipped} already in PostgreSQL. Source retained: #{path}"
        )

      {:error, reason} ->
        Mix.raise(
          "Cannot read legacy store: #{inspect(reason)}. Stop the old server before importing."
        )
    end
  end
end
