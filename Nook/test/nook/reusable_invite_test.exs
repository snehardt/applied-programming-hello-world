defmodule Nook.ReusableInviteTest do
  use Nook.DataCase, async: false
  alias Nook.{Boards, Access, Repo}

  test "copy reuses an encrypted invitation without revoking admitted guests" do
    owner = Access.new_guest()
    guest = Access.new_guest()
    code = Boards.create(owner)["code"]
    assert {:ok, token} = Boards.manage(:ensure_invite, code, owner)
    assert {:ok, :ok} = Boards.Store.redeem(code, token, guest, :invite)
    record = Repo.get!(Boards.Board, code)
    epoch = record.access_epoch
    assert record.access_epoch == 0
    assert record.invite_cipher != token
    assert {:ok, ^token} = Boards.manage(:ensure_invite, code, owner)
    assert Repo.get!(Boards.Board, code).access_epoch == epoch
    assert {:ok, _} = Boards.get(code, guest)
    assert {:error, :not_found} = Boards.manage(:ensure_invite, code, guest)
    assert {:ok, new_token} = Boards.manage(:issue_invite, code, owner)
    refute new_token == token
    assert {:error, :not_found} = Boards.get(code, guest)
    assert {:ok, ^new_token} = Boards.manage(:ensure_invite, code, owner)
  end

  test "unrecoverable older invitation requires explicit replacement without silent revocation" do
    owner = Access.new_guest()
    code = Boards.create(owner)["code"]
    {:ok, _} = Boards.manage(:issue_invite, code, owner)
    record = Repo.get!(Boards.Board, code)
    Repo.update!(Ecto.Changeset.change(record, invite_cipher: nil))
    assert {:error, :link_unavailable} = Boards.manage(:ensure_invite, code, owner)
    assert Repo.get!(Boards.Board, code).access_epoch == record.access_epoch
  end

  test "disabling clears recoverable link and later copying creates a fresh one" do
    owner = Access.new_guest()
    code = Boards.create(owner)["code"]
    {:ok, token} = Boards.manage(:ensure_invite, code, owner)
    assert {:ok, :ok} = Boards.manage(:disable_sharing, code, owner)
    assert Repo.get!(Boards.Board, code).invite_cipher == nil
    assert {:ok, new_token} = Boards.manage(:ensure_invite, code, owner)
    refute new_token == token
    {:ok, snapshot} = Boards.get(code, owner)
    refute Map.has_key?(snapshot, "invite_cipher")
    refute Map.has_key?(snapshot, "invite_hash")
  end
end
