defmodule Nook.Access do
  @moduledoc "A caller built only from the signed browser session. User tokens are revalidated on use."
  import Ecto.Query
  alias Nook.{Repo, Accounts}
  alias Nook.Boards.Grant
  defstruct [:guest_id, :user_token]

  def from_session(session),
    do: %__MODULE__{guest_id: session["guest_id"], user_token: session["user_token"]}

  def new_guest, do: %__MODULE__{guest_id: secret()}
  def secret, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  def hash(value) when is_binary(value), do: :crypto.hash(:sha256, value)
  def hash(_), do: nil
  def matches?(nil, _), do: false
  def matches?(_, nil), do: false
  def matches?(a, b) when byte_size(a) == byte_size(b), do: Plug.Crypto.secure_compare(a, b)
  def matches?(_, _), do: false

  def user(%__MODULE__{user_token: token}) when is_binary(token) do
    case Accounts.get_user_by_session_token(token) do
      {%{confirmed_at: confirmed} = user, _} when not is_nil(confirmed) -> user
      _ -> nil
    end
  end

  def user(_), do: nil

  def guest_owner?(board, %__MODULE__{} = actor),
    do: is_nil(board.owner_id) and matches?(board.guest_owner_hash, hash(actor.guest_id))

  def owner?(board, actor) do
    if board.owner_id,
      do: match?(%{id: id} when id == board.owner_id, user(actor)),
      else: guest_owner?(board, actor)
  end

  def active?(board) do
    is_nil(board.deleted_at) and is_nil(board.expired_at) and
      (is_nil(board.expires_at) or DateTime.compare(board.expires_at, DateTime.utc_now()) == :gt)
  end

  def allowed?(board, %__MODULE__{} = actor, permission \\ :read) do
    active?(board) and
      (owner?(board, actor) or (permission in [:read, :write] and invited?(board, actor)))
  end

  defp invited?(board, actor) do
    guest_hash = hash(actor.guest_id)

    is_binary(guest_hash) and
      Repo.exists?(
        from(g in Grant,
          where:
            g.board_code == ^board.code and g.guest_hash == ^guest_hash and
              g.access_epoch == ^board.access_epoch and
              (g.source == "approval" or
                 (g.source == "invitation" and ^board.sharing_enabled and
                    g.invite_hash == ^(board.invite_hash || <<>>)))
        )
      )
  end

  def lifetime_seconds, do: Application.get_env(:nook, :guest_inactivity_days, 7) * 86_400

  def activity(board) do
    now = DateTime.utc_now()

    [
      last_active_at: now,
      expires_at:
        if(board.owner_id, do: nil, else: DateTime.add(now, lifetime_seconds(), :second))
    ]
  end
end
