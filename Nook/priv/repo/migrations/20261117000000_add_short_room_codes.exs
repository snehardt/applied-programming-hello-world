defmodule Nook.Repo.Migrations.AddShortRoomCodes do
  use Ecto.Migration

  def up do
    alter table(:boards) do
      add(:room_code, :string)
    end

    create(unique_index(:boards, [:room_code]))
    flush()

    for [code] <- repo().query!("SELECT code FROM boards WHERE room_code IS NULL").rows do
      assign_code(code)
    end
  end

  defp assign_code(code) do
    short = :crypto.strong_rand_bytes(4) |> Base.encode32(padding: false) |> binary_part(0, 6)

    result =
      repo().query!(
        "UPDATE boards SET room_code = $1 WHERE code = $2 AND NOT EXISTS (SELECT 1 FROM boards WHERE room_code = $1)",
        [short, code]
      )

    if result.num_rows == 0, do: assign_code(code)
  end

  def down do
    drop(index(:boards, [:room_code]))
    alter(table(:boards), do: remove(:room_code))
  end
end
