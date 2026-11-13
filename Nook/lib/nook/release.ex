defmodule Nook.Release do
  @moduledoc "Database maintenance entry points for an offline-built release."
  def migrate do
    Application.load(:nook)

    for repo <- Application.fetch_env!(:nook, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end
end
