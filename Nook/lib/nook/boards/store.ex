defmodule Nook.Boards.Store do
  @moduledoc false
  import Ecto.Query
  alias Nook.{Repo, Access}
  alias Nook.Boards.{Board, Element, Grant}
  @geometry ~w(id type x y w h z revision)

  def create(code, actor, kind) do
    user = Access.user(actor)

    cond do
      is_nil(actor.guest_id) ->
        {:error, :unauthorized}

      kind == :permanent and is_nil(user) ->
        {:error, :unauthorized}

      kind not in [:guest, :permanent] ->
        {:error, :invalid}

      true ->
        record = %Board{
          code: code,
          owner_id: if(kind == :permanent, do: user.id),
          guest_owner_hash: if(kind == :guest, do: Access.hash(actor.guest_id)),
          legacy_access: false
        }

        record
        |> Ecto.Changeset.change(Access.activity(record))
        |> Repo.insert!()
        |> snapshot(actor)
    end
  end

  def get(code) do
    case Repo.get(Board, code) do
      nil -> {:error, :not_found}
      record -> {:ok, snapshot(record)}
    end
  end

  def get(code, actor) do
    Repo.transaction(fn ->
      record = locked!(code)
      authorize!(record, actor, :read)
      record |> touch() |> snapshot(actor)
    end)
  end

  def transact(code, actor, operation, permission \\ :write) do
    Repo.transaction(fn ->
      record = locked!(code)
      authorize!(record, actor, permission)
      before = snapshot(record, actor)

      case operation.(before) do
        {:ok, after_board} ->
          persist(record, before, after_board)
          {:changed, snapshot(Repo.get!(Board, code), actor)}

        {:duplicate, revision} ->
          {:duplicate, revision}

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  def import_snapshot(%{"code" => code} = board) do
    Repo.transaction(fn ->
      # Import never overwrites a board already saved in PostgreSQL.
      if Repo.get(Board, code) do
        :skipped
      else
        record = %Board{code: code, legacy_access: true}
        record = record |> Ecto.Changeset.change(Access.activity(record)) |> Repo.insert!()
        persist(record, %{"elements" => %{}}, board)
        :imported
      end
    end)
  end

  defp snapshot(record, actor \\ nil) do
    elements = Repo.all(from(e in Element, where: e.board_code == ^record.code))

    %{
      "code" => record.code,
      "title" => record.title,
      "revision" => record.revision,
      "recent_operations" => record.recent_operations,
      "kind" => if(record.owner_id, do: "permanent", else: "guest"),
      "expires_at" => if(record.expires_at, do: DateTime.to_iso8601(record.expires_at)),
      "can_manage" => !!(actor && Access.owner?(record, actor)),
      "can_claim" => !!(actor && Access.guest_owner?(record, actor) && Access.user(actor)),
      "sharing_enabled" => record.sharing_enabled,
      "sharing_active" => Nook.Rooms.shared?(record),
      "room_open" => record.room_open,
      "elements" =>
        Map.new(elements, fn el ->
          geometry = %{
            "id" => el.id,
            "type" => el.type,
            "x" => el.x,
            "y" => el.y,
            "z" => el.z,
            "revision" => el.revision
          }

          geometry =
            if el.type == "connection",
              do: geometry,
              else: Map.merge(geometry, %{"w" => el.w, "h" => el.h})

          {el.id, Map.merge(el.content, geometry)}
        end)
    }
  end

  defp persist(record, before, after_board) do
    Ecto.Changeset.change(
      record,
      Access.activity(record) ++
        [
          title: after_board["title"],
          revision: after_board["revision"],
          recent_operations: Map.get(after_board, "recent_operations", [])
        ]
    )
    |> Repo.update!()

    removed =
      for {id, _} <- before["elements"], !Map.has_key?(after_board["elements"], id), do: id

    if removed != [],
      do:
        Repo.delete_all(
          from(e in Element, where: e.board_code == ^record.code and e.id in ^removed)
        )

    existing_records =
      Repo.all(from(e in Element, where: e.board_code == ^record.code)) |> Map.new(&{&1.id, &1})

    for {id, el} <- after_board["elements"], before["elements"][id] != el do
      existing =
        Map.get(existing_records, id) ||
          %Element{board_code: record.code, id: id}

      attrs = [
        type: el["type"],
        x: el["x"] / 1,
        y: el["y"] / 1,
        w: number(el["w"]),
        h: number(el["h"]),
        z: el["z"] || 0,
        revision: (existing.revision || 0) + 1,
        content: Map.drop(el, @geometry)
      ]

      existing |> Ecto.Changeset.change(attrs) |> Repo.insert_or_update!()
    end
  end

  defp number(nil), do: nil
  defp number(n), do: n / 1

  def authorized?(code, actor, permission \\ :read) do
    case Repo.get(Board, code) do
      nil -> false
      record -> Access.allowed?(record, actor, permission)
    end
  end

  def issue_invite(code, actor), do: manage(code, actor, &write_invite/1)

  def ensure_invite(code, actor) do
    manage(code, actor, fn record ->
      if record.sharing_enabled && record.invite_hash do
        with cipher when is_binary(cipher) <- record.invite_cipher,
             {:ok, token} <-
               Phoenix.Token.decrypt(NookWeb.Endpoint, "nook-invite-storage", cipher,
                 max_age: :infinity
               ),
             true <- Access.matches?(record.invite_hash, Access.hash(token)) do
          token
        else
          _ -> Repo.rollback(:link_unavailable)
        end
      else
        write_invite(record, false)
      end
    end)
  end

  defp write_invite(record, rotate \\ true) do
    token = Access.secret()

    record
    |> Ecto.Changeset.change(
      invite_hash: Access.hash(token),
      invite_cipher: Phoenix.Token.encrypt(NookWeb.Endpoint, "nook-invite-storage", token),
      sharing_enabled: true,
      access_epoch: record.access_epoch + if(rotate, do: 1, else: 0)
    )
    |> Repo.update!()

    token
  end

  def disable_sharing(code, actor) do
    manage(code, actor, fn record ->
      record
      |> Ecto.Changeset.change(
        invite_hash: nil,
        invite_cipher: nil,
        sharing_enabled: false,
        room_open: false,
        access_epoch: record.access_epoch + 1
      )
      |> Repo.update!()

      :ok
    end)
  end

  def claim(code, actor) do
    manage(code, actor, fn record ->
      user = Access.user(actor)
      unless user && Access.guest_owner?(record, actor), do: Repo.rollback(:unauthorized)

      record
      |> Ecto.Changeset.change(
        owner_id: user.id,
        guest_owner_hash: nil,
        recovery_hash: nil,
        expires_at: nil,
        invite_hash: nil,
        invite_cipher: nil,
        sharing_enabled: false,
        room_open: false,
        access_epoch: record.access_epoch + 1,
        legacy_access: false
      )
      |> Repo.update!()

      :ok
    end)
  end

  def delete(code, actor) do
    manage(code, actor, fn record ->
      record
      |> Ecto.Changeset.change(
        deleted_at: DateTime.utc_now(),
        room_open: false,
        access_epoch: record.access_epoch + 1,
        sharing_enabled: false,
        invite_hash: nil,
        invite_cipher: nil
      )
      |> Repo.update!()

      :ok
    end)
  end

  def restore(code, actor) do
    Repo.transaction(fn ->
      record = locked!(code)
      unless record.owner_id && Access.owner?(record, actor), do: Repo.rollback(:unauthorized)
      record |> Ecto.Changeset.change(deleted_at: nil) |> Repo.update!()
      :ok
    end)
  end

  def redeem(code, token, actor, mode) when is_binary(token) and byte_size(token) == 43 do
    Repo.transaction(fn ->
      record = locked!(code)
      unless Access.active?(record) && actor.guest_id, do: Repo.rollback(:not_found)
      token_hash = Access.hash(token)

      case mode do
        :invite ->
          unless record.sharing_enabled && Access.matches?(record.invite_hash, token_hash),
            do: Repo.rollback(:not_found)

          Repo.insert!(
            %Grant{
              board_code: code,
              guest_hash: Access.hash(actor.guest_id),
              invite_hash: token_hash,
              source: "invitation",
              access_epoch: record.access_epoch
            },
            on_conflict: {:replace, [:invite_hash, :source, :access_epoch, :updated_at]},
            conflict_target: [:board_code, :guest_hash]
          )

        :recovery ->
          unless Access.matches?(record.recovery_hash, token_hash), do: Repo.rollback(:not_found)

          record
          |> Ecto.Changeset.change(
            guest_owner_hash: Access.hash(actor.guest_id),
            recovery_hash: nil
          )
          |> Repo.update!()
      end

      touch(record)
      :ok
    end)
  end

  def redeem(_, _, _, _), do: {:error, :not_found}

  def list_owned(actor, deleted \\ false) do
    case Access.user(actor) do
      nil ->
        []

      user ->
        Repo.all(
          from(b in Board,
            where: b.owner_id == ^user.id and is_nil(b.deleted_at) != ^deleted,
            order_by: [desc: b.updated_at]
          )
        )
    end
  end

  def list_guest(actor) do
    hash = Access.hash(actor.guest_id)

    if hash do
      Repo.all(
        from(b in Board,
          where:
            b.guest_owner_hash == ^hash and is_nil(b.owner_id) and is_nil(b.deleted_at) and
              b.expires_at > ^DateTime.utc_now(),
          order_by: [desc: b.updated_at]
        )
      )
    else
      []
    end
  end

  def expire_due do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      codes =
        Repo.all(
          from(b in Board,
            where: is_nil(b.owner_id) and is_nil(b.expired_at) and b.expires_at <= ^now,
            select: b.code,
            lock: "FOR UPDATE"
          )
        )

      Repo.update_all(from(b in Board, where: b.code in ^codes), set: [expired_at: now])
      codes
    end)
  end

  defp locked!(code) do
    Repo.one(from(b in Board, where: b.code == ^code, lock: "FOR UPDATE")) ||
      Repo.rollback(:not_found)
  end

  defp authorize!(record, actor, permission) do
    unless Access.allowed?(record, actor, permission), do: Repo.rollback(:not_found)
  end

  defp touch(record),
    do: record |> Ecto.Changeset.change(Access.activity(record)) |> Repo.update!()

  defp manage(code, actor, operation) do
    Repo.transaction(fn ->
      record = locked!(code)
      authorize!(record, actor, :manage)
      operation.(record)
    end)
  end
end
