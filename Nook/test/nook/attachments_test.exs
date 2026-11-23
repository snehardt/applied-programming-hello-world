defmodule Nook.AttachmentsTest do
  use NookWeb.ConnCase, async: false
  import Ecto.Query
  alias Nook.{Attachments, Boards, Repo, Attachment}

  setup do
    actor = Nook.Access.new_guest()
    board = Boards.create(actor)
    %{actor: actor, code: board["code"]}
  end

  defp upload(data, name \\ "plan.txt", mime \\ "text/plain") do
    path = Path.join(System.tmp_dir!(), "nook-attachment-#{System.unique_integer([:positive])}")
    File.write!(path, data)
    on_exit(fn -> File.rm(path) end)
    %Plug.Upload{path: path, filename: name, content_type: mime}
  end

  defp element(ref, id \\ "file"),
    do: Map.merge(ref, %{"id" => id, "type" => "file", "x" => 0, "y" => 0, "w" => 280, "h" => 90})

  test "large uploads stay out of snapshots, deduplicate, and survive removal and restoration", %{
    actor: actor,
    code: code
  } do
    bytes = String.duplicate("abc", 500_000)
    file = upload(bytes)
    assert {:ok, ref} = Attachments.upload(code, actor, file)
    assert {:ok, ^ref} = Attachments.upload(code, actor, file)
    assert Repo.aggregate(Attachment, :count) == 1
    assert {:ok, 1} = Boards.apply_op(code, %{"type" => "put", "element" => element(ref)}, actor)
    assert {:ok, snapshot} = Boards.get(code, actor)
    assert byte_size(Jason.encode!(snapshot)) < 2000
    refute Map.has_key?(snapshot["elements"]["file"], "data")

    assert {:ok, 2} =
             Boards.apply_op(
               code,
               %{"type" => "delete", "id" => "file", "base_revision" => 1},
               actor
             )

    assert {:ok, %{data: ^bytes}} = Attachments.fetch(code, ref["asset_id"], actor, true)
    assert {:ok, 3} = Boards.apply_op(code, %{"type" => "put", "element" => element(ref)}, actor)
    assert {:ok, restored} = Boards.get(code, actor)
    assert restored["elements"]["file"]["asset_id"] == ref["asset_id"]
  end

  test "files require current board access and references cannot cross boards", %{
    actor: actor,
    code: code,
    conn: conn
  } do
    file = upload("private")
    assert {:ok, ref} = Attachments.upload(code, actor, file)
    stranger = Nook.Access.new_guest()
    assert {:error, :not_found} = Attachments.fetch(code, ref["asset_id"], stranger, true)
    assert {:error, :not_found} = Attachments.upload(code, stranger, file)
    other = Boards.create(actor)["code"]

    assert {:error, :limit} =
             Boards.apply_op(other, %{"type" => "put", "element" => element(ref)}, actor)

    assert {:error, :limit} =
             Boards.apply_op(
               code,
               %{"type" => "put", "element" => element(Map.put(ref, "mime", "text/html"))},
               actor
             )

    signed = init_test_session(conn, %{guest_id: actor.guest_id})
    response = get(signed, "/api/boards/#{code}/files/#{ref["asset_id"]}?download=1")
    assert response.status == 200
    assert response.resp_body == "private"

    assert get_resp_header(response, "content-disposition") == [
             "attachment; filename*=UTF-8''plan.txt"
           ]

    assert get_resp_header(response, "cache-control") == ["private, no-store"]

    assert get(recycle(conn), "/api/boards/#{code}/files/#{ref["asset_id"]}?download=1").status ==
             404

    assert {:ok, :ok} = Boards.manage(:delete, code, actor)
    assert {:error, :not_found} = Attachments.fetch(code, ref["asset_id"], actor, true)
  end

  test "previews are separate from unmodified originals", %{actor: actor, code: code} do
    original = <<137, 80, 78, 71, 13, 10, 26, 10, "original bytes">>
    preview = <<255, 216, 255, "preview bytes">>

    assert {:ok, ref} =
             Attachments.upload(
               code,
               actor,
               upload(original, "photo.png", "image/png"),
               upload(preview, "preview.jpg", "image/jpeg")
             )

    assert {:ok, %{data: ^preview, mime: "image/jpeg"}} =
             Attachments.fetch(code, ref["asset_id"], actor, false)

    assert {:ok, %{data: ^original, mime: "image/png"}} =
             Attachments.fetch(code, ref["asset_id"], actor, true)
  end

  test "invited collaborators can load files until their access is revoked", %{
    actor: actor,
    code: code
  } do
    assert {:ok, ref} = Attachments.upload(code, actor, upload("shared file"))
    guest = Nook.Access.new_guest()
    assert {:ok, token} = Boards.manage(:issue_invite, code, actor)
    assert {:ok, :ok} = Boards.Store.redeem(code, token, guest, :invite)
    assert {:ok, %{data: "shared file"}} = Attachments.fetch(code, ref["asset_id"], guest, true)
    assert {:ok, :ok} = Boards.manage(:disable_sharing, code, actor)
    assert {:error, :not_found} = Attachments.fetch(code, ref["asset_id"], guest, true)
    assert {:error, :not_found} = Attachments.upload(code, guest, upload("new file"))
  end

  test "legacy inline images migrate once without changing layout, IDs or revision", %{
    actor: actor,
    code: code
  } do
    data = "legacy image bytes"

    content = %{
      "name" => "old.png",
      "mime" => "image/png",
      "data" => "data:image/png;base64," <> Base.encode64(data),
      "rotation" => 810
    }

    Repo.insert!(%Nook.Boards.Element{
      board_code: code,
      id: "old",
      type: "file",
      x: 10.0,
      y: 20.0,
      w: 200.0,
      h: 90.0,
      revision: 7,
      content: content
    })

    assert {:ok, snapshot} = Boards.get(code, actor)
    el = snapshot["elements"]["old"]
    assert el["rotation"] == 810 and el["revision"] == 7 and el["x"] == 10
    assert {:ok, %{data: ^data}} = Attachments.fetch(code, el["asset_id"], actor, true)
    assert {:ok, again} = Boards.get(code, actor)
    assert again["elements"] == snapshot["elements"]
    assert again["revision"] == snapshot["revision"]
    assert Repo.aggregate(Attachment, :count) == 1

    refute Map.has_key?(
             Repo.get_by!(Nook.Boards.Element, board_code: code, id: "old").content,
             "data"
           )
  end

  test "file size, format, preview and storage budgets reject atomically", %{
    actor: actor,
    code: code
  } do
    assert {:error, :file_limit} = Attachments.upload(code, actor, upload(""))

    assert {:error, :file_limit} =
             Attachments.upload(code, actor, upload(String.duplicate("x", 10_000_001)))

    assert {:error, :invalid} =
             Attachments.upload(code, actor, upload("<html>", "bad.html", "text/html"))

    assert {:error, :invalid} =
             Attachments.upload(
               code,
               actor,
               upload("ok"),
               upload("<svg/>", "bad.png", "image/png")
             )

    Application.put_env(:nook, :attachment_max_bytes, 3)
    on_exit(fn -> Application.delete_env(:nook, :attachment_max_bytes) end)
    assert {:error, :storage_limit} = Attachments.upload(code, actor, upload("1234"))
    refute Repo.exists?(from(a in Attachment, where: a.board_code == ^code))
    assert {:ok, _} = Attachments.upload(code, actor, upload("123"))

    inline =
      element(%{
        "name" => "legacy.txt",
        "mime" => "text/plain",
        "data" => "data:text/plain;base64,MTIzNA=="
      })

    assert {:error, :storage_limit} =
             Boards.apply_op(code, %{"type" => "put", "element" => inline}, actor)

    assert {:ok, board} = Boards.get(code, actor)
    assert board["elements"] == %{}
    assert Repo.aggregate(Attachment, :count) == 1
  end
end
