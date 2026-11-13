defmodule Nook.Boards.Board do
  use Ecto.Schema
  @primary_key {:code, :string, autogenerate: false}
  schema "boards" do
    field(:title, :string, default: "Untitled board")
    field(:revision, :integer, default: 0)
    field(:recent_operations, {:array, :string}, default: [])
    belongs_to(:owner, Nook.Accounts.User)
    field(:guest_owner_hash, :binary)
    field(:invite_hash, :binary)
    field(:invite_cipher, :string)
    field(:recovery_hash, :binary)
    field(:sharing_enabled, :boolean, default: false)
    field(:room_open, :boolean, default: false)
    field(:access_epoch, :integer, default: 0)
    field(:legacy_access, :boolean, default: false)
    field(:last_active_at, :utc_datetime_usec)
    field(:expires_at, :utc_datetime_usec)
    field(:expired_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)
    has_many(:elements, Nook.Boards.Element, foreign_key: :board_code, references: :code)
    timestamps(type: :utc_datetime_usec)
  end
end
