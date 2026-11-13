defmodule Nook.Boards.Grant do
  use Ecto.Schema

  schema "board_grants" do
    field(:board_code, :string)
    field(:guest_hash, :binary)
    field(:invite_hash, :binary)
    field(:source, :string, default: "invitation")
    field(:access_epoch, :integer, default: 0)
    timestamps(type: :utc_datetime_usec)
  end
end
