defmodule Nook.BoardAccessTest do
  use Nook.DataCase, async: false
  alias Nook.{Access, Accounts, Boards, Repo}
  alias Nook.Boards.{Board, Store}
  import Nook.AccountsFixtures

  defp member(guest \\ Access.new_guest()) do
    user = user_fixture()
    {%{guest | user_token: Accounts.generate_user_session_token(user)}, user}
  end

  defp note,
    do: %{
      "type" => "put",
      "element" => %{
        "id" => "n",
        "type" => "note",
        "x" => 0,
        "y" => 0,
        "w" => 230,
        "h" => 200,
        "text" => "Private idea"
      }
    }

  test "a room code alone cannot read, edit, rename, claim or share a guest board" do
    creator = Access.new_guest()
    stranger = Access.new_guest()
    code = Boards.create(creator)["code"]
    assert {:ok, 1} = Boards.apply_op(code, note(), creator)
    assert {:error, :not_found} = Boards.get(code, stranger)
    assert {:error, :not_found} = Boards.apply_op(code, note(), stranger)

    for action <- [:claim, :issue_invite, :disable_sharing, :delete] do
      assert {:error, :not_found} = Boards.manage(action, code, stranger)
    end

    assert {:ok, %{"elements" => %{"n" => _}}} = Boards.get(code, creator)
  end

  test "invitation grants editing but not ownership or management, and rotation revokes it" do
    creator = Access.new_guest()
    {guest, _} = member()
    code = Boards.create(creator)["code"]
    {:ok, token} = Boards.manage(:issue_invite, code, creator)
    assert {:error, :not_found} = Store.redeem(code, Access.secret(), guest, :invite)
    assert {:ok, :ok} = Store.redeem(code, token, guest, :invite)
    assert {:ok, 1} = Boards.apply_op(code, note(), guest)
    assert {:error, :not_found} = Boards.manage(:claim, code, guest)

    assert {:error, :not_found} =
             Boards.apply_op(code, %{"type" => "rename", "title" => "Hijacked"}, guest)

    {:ok, replacement} = Boards.manage(:issue_invite, code, creator)
    refute replacement == token
    refute Store.authorized?(code, guest)
    assert {:error, :not_found} = Store.redeem(code, token, guest, :invite)
    assert {:ok, :ok} = Store.redeem(code, replacement, guest, :invite)
    assert {:ok, :ok} = Boards.manage(:disable_sharing, code, creator)
    refute Store.authorized?(code, guest)
    assert {:error, :not_found} = Store.redeem(code, replacement, guest, :invite)
  end

  test "claiming requires a confirmed account and creator identity and preserves content" do
    creator = Access.new_guest()
    visitor = Access.new_guest()
    code = Boards.create(creator)["code"]
    Boards.apply_op(code, note(), creator)
    {:ok, link} = Boards.manage(:issue_invite, code, creator)
    Store.redeem(code, link, visitor, :invite)
    assert {:error, :unauthorized} = Boards.manage(:claim, code, creator)
    {owner, user} = member(creator)
    assert {:ok, :ok} = Boards.manage(:claim, code, owner)

    assert {:ok, %{"kind" => "permanent", "expires_at" => nil, "elements" => %{"n" => _}}} =
             Boards.get(code, owner)

    record = Repo.get!(Board, code)
    assert record.owner_id == user.id
    assert is_nil(record.guest_owner_hash)
    refute record.sharing_enabled
    refute Store.authorized?(code, visitor)
    refute Store.authorized?(code, creator)
    assert {:error, :unauthorized} = Boards.manage(:claim, code, owner)
  end

  test "guest expiry is enforced before reads and writes, and unauthorized requests never refresh it" do
    creator = Access.new_guest()
    code = Boards.create(creator)["code"]
    initial = Repo.get!(Board, code)
    assert DateTime.diff(initial.expires_at, initial.last_active_at) == 7 * 86_400
    assert {:error, :not_found} = Boards.get(code, Access.new_guest())
    assert Repo.get!(Board, code).expires_at == initial.expires_at

    initial
    |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -1))
    |> Repo.update!()

    assert {:error, :not_found} = Boards.get(code, creator)
    assert {:error, :not_found} = Boards.apply_op(code, note(), creator)
    {account, _} = member(creator)
    assert {:error, :not_found} = Boards.manage(:claim, code, account)
    assert {:ok, [^code]} = Store.expire_due()
    assert Repo.get!(Board, code).expired_at
    # Content is retained; expiry never destroys a user's board rows.
    assert Repo.get!(Board, code)
  end

  test "permanent boards are private, isolated by owner and inaccessible after session revocation" do
    {owner, _} = member()
    {other, _} = member()
    code = Boards.create(owner, :permanent)["code"]
    assert {:error, :unauthorized} = Boards.create(Access.new_guest(), :permanent)
    assert {:ok, %{"expires_at" => nil}} = Boards.get(code, owner)
    assert {:error, :not_found} = Boards.get(code, other)
    assert Enum.map(Store.list_owned(owner), & &1.code) == [code]
    assert Store.list_owned(other) == []
    Accounts.delete_user_session_token(owner.user_token)
    refute Store.authorized?(code, owner)
    assert Store.list_owned(owner) == []
    assert {:error, :not_found} = Boards.apply_op(code, note(), owner)
  end

  test "soft deletion revokes access and only its owner can restore a board" do
    {owner, _} = member()
    {other, _} = member()
    code = Boards.create(owner, :permanent)["code"]
    Boards.apply_op(code, note(), owner)
    assert {:error, :not_found} = Boards.manage(:delete, code, other)
    assert {:ok, :ok} = Boards.manage(:delete, code, owner)
    assert {:error, :not_found} = Boards.get(code, owner)
    assert Store.list_owned(owner) == []
    assert [%{code: ^code}] = Store.list_owned(owner, true)
    assert {:error, :unauthorized} = Boards.manage(:restore, code, other)
    assert {:ok, :ok} = Boards.manage(:restore, code, owner)
    assert {:ok, %{"elements" => %{"n" => _}}} = Boards.get(code, owner)
  end

  test "recovery links are one-use and confer creator access without exposing it through the code" do
    visitor = Access.new_guest()
    board = %Board{code: "LEGACYRECOVER1", legacy_access: false}
    recovery = Access.secret()

    board
    |> Ecto.Changeset.change(Access.activity(board) ++ [recovery_hash: Access.hash(recovery)])
    |> Repo.insert!()

    assert {:error, :not_found} = Boards.get(board.code, visitor)
    assert {:ok, :ok} = Store.redeem(board.code, recovery, visitor, :recovery)
    assert {:ok, %{"can_manage" => true}} = Boards.get(board.code, visitor)

    assert {:error, :not_found} =
             Store.redeem(board.code, recovery, Access.new_guest(), :recovery)
  end
end
