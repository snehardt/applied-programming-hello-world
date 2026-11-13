defmodule Nook.Boards.Element do
  use Ecto.Schema
  @primary_key false
  schema "elements" do
    field(:board_code, :string, primary_key: true)
    field(:id, :string, primary_key: true)
    field(:type, :string)
    field(:x, :float)
    field(:y, :float)
    field(:w, :float)
    field(:h, :float)
    field(:z, :integer, default: 0)
    field(:revision, :integer, default: 0)
    field(:content, :map, default: %{})
    timestamps(type: :utc_datetime_usec)
  end
end
