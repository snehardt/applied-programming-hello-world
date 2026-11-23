defmodule NookWeb.BoardChannelTest do
  use Nook.DataCase, async: false
  import Phoenix.ChannelTest
  alias Nook.{Access, Boards, Accounts}
  @endpoint NookWeb.Endpoint
  defp connection(actor),
    do: socket(NookWeb.UserSocket, "test", %{actor: actor, visitor_id: Access.secret()})

  test "drawing previews are bounded, throttled, attributed by the server and never persisted" do
    owner = Access.new_guest()
    code = Boards.create(owner)["code"]

    {:ok, _, sender} =
      subscribe_and_join(connection(owner), NookWeb.BoardChannel, "board:" <> code)

    {:ok, _, _receiver} =
      subscribe_and_join(connection(owner), NookWeb.BoardChannel, "board:" <> code)

    preview = %{
      "visible" => true,
      "points" => [[-10, 20], [50, 70]],
      "color" => "#210a3b",
      "width" => 4,
      "linear" => true,
      "opacity" => 0.3,
      "id" => "forged"
    }

    push(sender, "drawing", preview)
    assert_push("drawing", %{"id" => id, "visible" => true, "linear" => true, "opacity" => 0.3})
    refute id == "forged"
    push(sender, "drawing", preview)
    refute_push("drawing", _, 20)
    push(sender, "drawing", Map.put(preview, "points", List.duplicate([0, 0], 129)))
    refute_push("drawing", _, 20)
    push(sender, "drawing", Map.put(preview, "opacity", "invalid"))
    refute_push("drawing", _, 20)
    push(sender, "drawing", %{"visible" => false})
    assert_push("drawing", %{"visible" => false})
    {:ok, board} = Boards.get(code, owner)
    assert board["elements"] == %{}
  end

  test "group previews use one bounded message and never persist or forward invalid data" do
    owner = Access.new_guest()
    code = Boards.create(owner)["code"]

    {:ok, _, sender} =
      subscribe_and_join(connection(owner), NookWeb.BoardChannel, "board:" <> code)

    {:ok, _, _receiver} =
      subscribe_and_join(connection(owner), NookWeb.BoardChannel, "board:" <> code)

    elements = [
      %{"id" => "a", "changes" => %{"x" => 50}, "extra" => "omit"},
      %{"id" => "b", "changes" => %{"y" => 60}}
    ]

    push(sender, "previews", %{"elements" => elements})
    assert_push("previews", %{elements: [first, _]})
    refute Map.has_key?(first, "extra")
    {:ok, board} = Boards.get(code, owner)
    assert board["elements"] == %{}

    push(sender, "previews", %{
      "elements" => [%{"id" => "a", "changes" => %{"text" => "Not geometry"}}]
    })

    refute_push("previews", _, 80)
  end

  test "cursors use server identity, reject malformed positions, and respect live revocation" do
    owner = Access.new_guest()
    guest = Access.new_guest()
    code = Boards.create(owner)["code"]
    {:ok, token} = Boards.manage(:issue_invite, code, owner)
    Boards.Store.redeem(code, token, guest, :invite)

    {:ok, _, owner_socket} =
      subscribe_and_join(connection(owner), NookWeb.BoardChannel, "board:" <> code, %{
        "name" => "Owner name"
      })

    {:ok, _, _guest_socket} =
      subscribe_and_join(connection(guest), NookWeb.BoardChannel, "board:" <> code)

    push(owner_socket, "cursor", %{
      "visible" => true,
      "x" => 40,
      "y" => -15,
      "name" => "Forged",
      "color" => "script"
    })

    assert_push("cursor", %{name: "Owner name", x: 40, y: -15, visible: true, id: id})
    assert is_binary(id)
    push(owner_socket, "cursor", %{"visible" => false})
    assert_push("cursor", %{visible: false})
    push(owner_socket, "cursor", %{"visible" => true, "x" => "bad", "y" => 0})
    refute_push("cursor", _, 80)
    Boards.manage(:disable_sharing, code, owner)
    assert_push("access_lost", _)
  end

  test "wire operations enforce revisions and emit canonical element versions without recovery data" do
    owner = Access.new_guest()
    code = Boards.create(owner)["code"]

    {:ok, joined, socket} =
      subscribe_and_join(connection(owner), NookWeb.BoardChannel, "board:" <> code, %{
        "name" => "Spencer"
      })

    assert joined["self"].role == "Owner"

    el = %{
      "id" => "n",
      "type" => "note",
      "text" => "Original",
      "x" => 0,
      "y" => 0,
      "w" => 230,
      "h" => 200
    }

    ref = push(socket, "operation", %{"type" => "put", "element" => el})
    assert_reply(ref, :ok, %{snapshot: %{"elements" => %{"n" => %{"revision" => 1}}}})

    ref =
      push(socket, "operation", %{
        "type" => "patch",
        "id" => "n",
        "changes" => %{"text" => "No version"}
      })

    assert_reply(ref, :error, %{reason: "conflict"})

    ref =
      push(socket, "operation", %{
        "type" => "patch",
        "id" => "n",
        "base_revision" => 1,
        "base" => %{"text" => "Original"},
        "changes" => %{"text" => "New"},
        "recovery_element" => %{"private" => "local"}
      })

    assert_reply(ref, :ok, %{revision: 2})
    assert_push("operation", %{"revision" => 1})
    assert_push("operation", %{"op" => op, "revision" => 2})
    assert op["element_revision"] == 2
    refute Map.has_key?(op, "base")
    refute Map.has_key?(op, "recovery_element")
  end

  test "a guessed room code cannot join a channel" do
    owner = Access.new_guest()
    code = Boards.create(owner)["code"]

    assert {:error, %{reason: "Board not found"}} =
             subscribe_and_join(
               connection(Access.new_guest()),
               NookWeb.BoardChannel,
               "board:" <> code
             )
  end

  test "turning off invitations immediately removes an already connected guest" do
    owner = Access.new_guest()
    guest = Access.new_guest()
    code = Boards.create(owner)["code"]
    {:ok, token} = Boards.manage(:issue_invite, code, owner)
    {:ok, :ok} = Boards.Store.redeem(code, token, guest, :invite)

    {:ok, _, _socket} =
      subscribe_and_join(connection(guest), NookWeb.BoardChannel, "board:" <> code)

    assert {:ok, :ok} = Boards.manage(:disable_sharing, code, owner)
    assert_push("access_lost", %{message: _})

    NookWeb.Endpoint.broadcast("board:" <> code, "operation", %{
      op: %{private: "must not arrive"},
      revision: 99
    })

    refute_push("operation", _, 100)
  end

  test "a revoked login session cannot submit edits over an existing socket" do
    user = Nook.AccountsFixtures.user_fixture()
    owner = %{Access.new_guest() | user_token: Accounts.generate_user_session_token(user)}
    code = Boards.create(owner, :permanent)["code"]

    {:ok, _, socket} =
      subscribe_and_join(connection(owner), NookWeb.BoardChannel, "board:" <> code)

    assert_push("presence_state", _)
    assert_push("presence_diff", _)

    Accounts.delete_user_session_token(owner.user_token)
    ref = push(socket, "operation", %{"type" => "rename", "title" => "No longer allowed"})
    assert_reply(ref, :error, %{reason: :not_found})
  end
end
