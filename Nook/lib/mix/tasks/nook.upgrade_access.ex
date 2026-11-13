defmodule Mix.Tasks.Nook.UpgradeAccess do
  use Mix.Task
  import Ecto.Query
  alias Nook.{Repo, Access}
  alias Nook.Boards.Board
  @shortdoc "Preserve legacy boards with one-use recovery links saved locally"
  def run(_) do
    Mix.Task.run("app.start")
    path = Path.expand(".nook-history/legacy-board-recovery.json")
    existing = if File.exists?(path), do: path |> File.read!() |> Jason.decode!(), else: %{}

    {:ok, count} =
      Repo.transaction(fn ->
        records = Repo.all(from(b in Board, where: b.legacy_access == true, lock: "FOR UPDATE"))

        links =
          Enum.reduce(records, existing, fn record, acc ->
            token = Access.secret()

            record
            |> Ecto.Changeset.change(
              Access.activity(record) ++ [recovery_hash: Access.hash(token), legacy_access: false]
            )
            |> Repo.update!()

            Map.put(acc, record.code, %{
              "title" => record.title,
              "url" => "http://127.0.0.1:4000/recover/#{record.code}/#{token}"
            })
          end)

        if records != [] or not File.exists?(path) do
          File.mkdir_p!(Path.dirname(path))
          File.write!(path <> ".tmp", Jason.encode!(links, pretty: true))
          File.rename!(path <> ".tmp", path)
        end

        length(records)
      end)

    Mix.shell().info(
      "#{count} legacy recovery links prepared. Private local file: #{path}. Existing links retained."
    )

    recovery = path |> File.read!() |> Jason.decode!()

    markdown =
      "# Previous Nook boards\n\nThese one-use links establish creator access in the browser that opens them. Then sign in and save the board permanently. Unclaimed boards expire after seven days of inactivity. After recovery, reopen the board through its normal board URL.\n\n" <>
        Enum.map_join(Enum.sort(recovery), "\n", fn {code, entry} ->
          "- [Recover board #{code}](#{entry["url"]})"
        end) <> "\n"

    File.write!(Path.rootname(path) <> ".md", markdown)
  end
end
