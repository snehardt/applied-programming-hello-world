defmodule Nook.Attachment do
  use Ecto.Schema
  @primary_key {:id, :string, autogenerate: false}
  schema "attachments" do
    field(:board_code, :string)
    field(:name, :string)
    field(:mime, :string)
    field(:size, :integer)
    field(:data, :binary)
    field(:preview, :binary)
    field(:preview_mime, :string)
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
