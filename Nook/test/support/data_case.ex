defmodule Nook.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Nook.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Nook.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Nook.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  def errors_on(changeset),
    do: Ecto.Changeset.traverse_errors(changeset, &NookWeb.CoreComponents.translate_error/1)
end
