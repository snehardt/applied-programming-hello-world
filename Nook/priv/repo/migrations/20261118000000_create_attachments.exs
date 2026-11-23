defmodule Nook.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add(:id, :string, primary_key: true)

      add(:board_code, references(:boards, column: :code, type: :string, on_delete: :delete_all),
        null: false
      )

      add(:name, :string, null: false)
      add(:mime, :string, null: false)
      add(:size, :integer, null: false)
      add(:data, :binary, null: false)
      add(:preview, :binary)
      add(:preview_mime, :string)
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:attachments, [:board_code]))
  end
end
