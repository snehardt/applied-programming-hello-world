defmodule Nook.Repo.Migrations.AddBoardAccessAndLifetime do
  use Ecto.Migration
  def change do
    alter table(:boards) do
      add :owner_id, references(:users, on_delete: :restrict)
      add :guest_owner_hash, :binary
      add :invite_hash, :binary
      add :recovery_hash, :binary
      add :sharing_enabled, :boolean, null: false, default: false
      add :legacy_access, :boolean, null: false, default: true
      add :last_active_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
      add :expired_at, :utc_datetime_usec
      add :deleted_at, :utc_datetime_usec
    end
    # Give preserved pre-account boards a fresh recovery window during the upgrade.
    execute "UPDATE boards SET last_active_at = timezone('UTC', now()), expires_at = timezone('UTC', now()) + interval '7 days'", "SELECT 1"
    create index(:boards, [:owner_id, :updated_at])
    create index(:boards, [:expires_at], where: "owner_id IS NULL")
    create table(:board_grants) do
      add :board_code, references(:boards, column: :code, type: :string, on_delete: :delete_all), null: false
      add :guest_hash, :binary, null: false
      add :invite_hash, :binary, null: false
      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:board_grants, [:board_code, :guest_hash])
  end
end
