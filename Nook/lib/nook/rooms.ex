defmodule Nook.Rooms do
  @moduledoc "Session-bound room requests, approved only by the current board owner."
  import Ecto.Query
  alias Nook.{Access, Repo, Participants}
  alias Nook.Boards.{Board, Grant}
  alias Nook.Rooms.Request

  def shared?(board) do
    board.sharing_enabled or
      Repo.exists?(
        from(g in Grant,
          where:
            g.board_code == ^board.code and g.access_epoch == ^board.access_epoch and
              g.source == "approval"
        )
      )
  end

  def request(code, actor, label) do
    result =
      Repo.transaction(fn ->
        board = lock!(code)

        unless board.room_open and Access.active?(board) and is_binary(actor.guest_id),
          do: Repo.rollback(:unavailable)

        now = DateTime.utc_now()
        hash = Access.hash(actor.guest_id)
        existing = Repo.get_by(Request, board_code: code, guest_hash: hash)

        if existing && existing.access_epoch == board.access_epoch &&
             DateTime.compare(existing.expires_at, now) == :gt do
          public(existing)
        else
          count =
            Repo.aggregate(
              from(r in Request,
                where: r.board_code == ^code and r.status == "pending" and r.expires_at > ^now
              ),
              :count
            )

          total =
            Repo.aggregate(
              from(r in Request, where: r.guest_hash == ^hash and r.expires_at > ^now),
              :count
            )

          if count >= 50 or total >= 10, do: Repo.rollback(:unavailable)

          attrs = [
            id: Access.secret(),
            board_code: code,
            guest_hash: hash,
            display_name: Participants.name(label, actor),
            status: "pending",
            access_epoch: board.access_epoch,
            expires_at: DateTime.add(now, 600)
          ]

          if existing, do: Repo.delete!(existing)
          %Request{} |> Ecto.Changeset.change(attrs) |> Repo.insert!() |> public()
        end
      end)

    notify(code, result)
  end

  def status(id, actor) do
    request = Repo.get(Request, id)

    if request && Access.matches?(request.guest_hash, Access.hash(actor.guest_id)) do
      board = Repo.get(Board, request.board_code)

      cond do
        is_nil(board) or not Access.active?(board) or request.access_epoch != board.access_epoch or
            DateTime.compare(request.expires_at, DateTime.utc_now()) != :gt ->
          {:ok, %{status: "expired"}}

        request.status == "approved" and Access.allowed?(board, actor) ->
          {:ok, %{status: "approved", path: "/b/#{board.code}"}}

        not board.room_open and request.status == "pending" ->
          {:ok, %{status: "expired"}}

        true ->
          {:ok, public(request)}
      end
    else
      {:error, :unavailable}
    end
  end

  def list(code, actor) do
    Repo.transaction(fn ->
      board = lock!(code)
      owner!(board, actor)
      now = DateTime.utc_now()

      Repo.all(
        from(r in Request,
          where:
            r.board_code == ^code and r.access_epoch == ^board.access_epoch and
              r.status == "pending" and r.expires_at > ^now,
          order_by: r.inserted_at
        )
      )
      |> Enum.map(&public/1)
    end)
  end

  def set_open(code, actor, open) when is_boolean(open) do
    result =
      Repo.transaction(fn ->
        board = lock!(code)
        owner!(board, actor)
        board |> Ecto.Changeset.change(room_open: open) |> Repo.update!()
        # Closing cancels waiting requests; admitted editors retain access.
        unless open,
          do:
            Repo.update_all(
              from(r in Request, where: r.board_code == ^code and r.status == "pending"),
              set: [status: "denied"]
            )

        %{room_open: open}
      end)

    notify_access(code, result)
  end

  def decide(code, id, actor, decision) when decision in ["approved", "denied"] do
    result =
      Repo.transaction(fn ->
        board = lock!(code)
        owner!(board, actor)

        r =
          Repo.one(
            from(r in Request, where: r.id == ^id and r.board_code == ^code, lock: "FOR UPDATE")
          )

        unless board.room_open && r && r.status == "pending" &&
                 r.access_epoch == board.access_epoch &&
                 DateTime.compare(r.expires_at, DateTime.utc_now()) == :gt,
               do: Repo.rollback(:unavailable)

        r |> Ecto.Changeset.change(status: decision) |> Repo.update!()

        if decision == "approved" do
          Repo.insert!(
            %Grant{
              board_code: code,
              guest_hash: r.guest_hash,
              source: "approval",
              access_epoch: board.access_epoch
            },
            on_conflict: {:replace, [:source, :access_epoch, :invite_hash, :updated_at]},
            conflict_target: [:board_code, :guest_hash]
          )
        end

        %{ok: true}
      end)

    notify_access(code, result)
  end

  defp lock!(code),
    do:
      Repo.one(from(b in Board, where: b.code == ^code, lock: "FOR UPDATE")) ||
        Repo.rollback(:unavailable)

  defp owner!(board, actor),
    do: unless(Access.allowed?(board, actor, :manage), do: Repo.rollback(:unavailable))

  defp public(r), do: %{id: r.id, name: r.display_name, status: r.status}

  defp notify_access(code, result) do
    if match?({:ok, _}, result),
      do: NookWeb.Endpoint.broadcast("board:" <> code, "access_changed", %{})

    notify(code, result)
  end

  defp notify(code, result) do
    if match?({:ok, _}, result),
      do: NookWeb.Endpoint.broadcast("board:" <> code, "room_requests_changed", %{})

    result
  end
end
