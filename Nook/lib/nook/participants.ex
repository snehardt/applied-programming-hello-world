defmodule Nook.Participants do
  @moduledoc "Pseudonymous presence profiles; labels never confer permissions."
  def identity(actor) do
    value =
      case Nook.Access.user(actor) do
        nil -> "guest:" <> (actor.guest_id || "")
        user -> "user:#{user.id}"
      end

    :crypto.mac(:hmac, :sha256, NookWeb.Endpoint.config(:secret_key_base), value)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  def default_name(actor),
    do: "Guest " <> (identity(actor) |> binary_part(0, 4) |> String.upcase())

  def name(value, actor) when is_binary(value) do
    value = String.trim(value)

    if String.length(value) in 1..40 and byte_size(value) <= 160,
      do: value,
      else: default_name(actor)
  end

  def name(_, actor), do: default_name(actor)

  def profile(code, actor, label) do
    record = Nook.Repo.get(Nook.Boards.Board, code)
    key = identity(actor)
    colors = ~w(purple teal amber rose blue)

    %{
      id: key,
      name: name(label, actor),
      color: Enum.at(colors, rem(:binary.first(key), 5)),
      role: if(record && Nook.Access.owner?(record, actor), do: "Owner", else: "Editor")
    }
  end
end
