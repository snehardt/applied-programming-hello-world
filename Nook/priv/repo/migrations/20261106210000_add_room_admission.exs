defmodule Nook.Repo.Migrations.AddRoomAdmission do
  use Ecto.Migration
  def change do
    alter table(:boards) do
      add :room_open, :boolean, null: false, default: false
      add :access_epoch, :integer, null: false, default: 0
    end
    alter table(:board_grants) do
      add :source, :string, null: false, default: "invitation"
      add :access_epoch, :integer, null: false, default: 0
      modify :invite_hash, :binary, null: true, from: {:binary, null: false}
    end
    create table(:room_requests, primary_key: false) do
      add :id, :string, primary_key: true
      add :board_code, references(:boards, column: :code, type: :string, on_delete: :delete_all), null: false
      add :guest_hash, :binary, null: false
      add :display_name, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :access_epoch, :integer, null: false
      add :expires_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:room_requests, [:board_code, :guest_hash])
    create index(:room_requests, [:board_code, :status, :expires_at])
  end
end
