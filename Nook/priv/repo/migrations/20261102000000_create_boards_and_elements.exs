defmodule Nook.Repo.Migrations.CreateBoardsAndElements do
  use Ecto.Migration
  def change do
    create table(:boards, primary_key: false) do
      add :code, :string, primary_key: true
      add :title, :string, null: false, default: "Untitled board"
      add :revision, :bigint, null: false, default: 0
      add :recent_operations, {:array, :string}, null: false, default: []
      timestamps(type: :utc_datetime_usec)
    end
    create table(:elements, primary_key: false) do
      add :board_code, references(:boards, column: :code, type: :string, on_delete: :delete_all), primary_key: true
      add :id, :string, primary_key: true
      add :type, :string, null: false
      add :x, :float, null: false
      add :y, :float, null: false
      add :w, :float
      add :h, :float
      add :z, :integer, null: false, default: 0
      add :revision, :bigint, null: false, default: 0
      add :content, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec)
    end
    create index(:elements, [:board_code, :z])
    create constraint(:elements, :valid_geometry, check: "abs(x) < 10000000 AND abs(y) < 10000000 AND (w IS NULL OR w BETWEEN 50 AND 10000) AND (h IS NULL OR h BETWEEN 50 AND 10000)")
  end
end
