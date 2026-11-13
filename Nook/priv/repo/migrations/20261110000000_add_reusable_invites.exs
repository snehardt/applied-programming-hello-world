defmodule Nook.Repo.Migrations.AddReusableInvites do
  use Ecto.Migration
  def change do
    alter table(:boards), do: add(:invite_cipher, :text)
  end
end
