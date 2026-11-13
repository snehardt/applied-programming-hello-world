defmodule Nook.Rooms.Request do
  use Ecto.Schema
  @primary_key {:id, :string, autogenerate: false}
  schema "room_requests" do
    field(:board_code, :string)
    field(:guest_hash, :binary)
    field(:display_name, :string)
    field(:status, :string, default: "pending")
    field(:access_epoch, :integer)
    field(:expires_at, :utc_datetime_usec)
    timestamps(type: :utc_datetime_usec)
  end
end
