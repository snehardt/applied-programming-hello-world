defmodule Nook.Attachments do
  @moduledoc "Private, board-scoped originals and previews, kept outside canvas snapshots."
  import Ecto.Query
  alias Nook.{Attachment, Repo}
  @max_file 10_000_000
  @max_preview 1_000_000
  @mimes ~w(image/png image/jpeg image/gif image/webp application/pdf text/plain text/csv text/markdown)

  def upload(code, actor, %Plug.Upload{} = file, preview \\ nil) do
    Nook.Boards.Store.with_access(code, actor, :write, fn ->
      mime = if file.content_type in [nil, ""], do: "text/plain", else: file.content_type

      unless valid_name?(file.filename) and mime in @mimes and
               (file.content_type not in [nil, ""] or
                  Regex.match?(~r/\.(txt|md|csv)$/i, file.filename)),
             do: Repo.rollback(:invalid)

      data = read_upload!(file, @max_file)
      {preview_data, preview_mime} = read_preview!(preview)
      id = identity(code, file.filename, mime, data)

      ensure_capacity!(code, id, byte_size(data) + byte_size(preview_data || ""))

      insert(code, id, file.filename, mime, data, preview_data, preview_mime)
    end)
  end

  def reference?(code, id, name, mime)
      when is_binary(id) and is_binary(name) and is_binary(mime) do
    Repo.exists?(
      from(a in Attachment,
        where: a.id == ^id and a.board_code == ^code and a.name == ^name and a.mime == ^mime
      )
    )
  end

  def reference?(_, _, _, _), do: false

  def fetch(code, id, actor, download) do
    Nook.Boards.Store.with_access(code, actor, :read, fn ->
      query = from(a in Attachment, where: a.id == ^id and a.board_code == ^code)

      query =
        if download do
          from(a in query, select: %{data: a.data, mime: a.mime, name: a.name})
        else
          from(a in query,
            where: a.mime in ~w(image/png image/jpeg image/gif image/webp),
            select: %{
              data: fragment("coalesce(?, ?)", a.preview, a.data),
              mime: fragment("coalesce(?, ?)", a.preview_mime, a.mime),
              name: a.name
            }
          )
        end

      Repo.one(query) || Repo.rollback(:not_found)
    end)
  end

  # Legacy inline files are converted once, without changing element IDs or revisions.
  # Deterministic IDs make retries and concurrent reads safe; originals survive undo/replacement.
  def externalize(code, content, enforce_quota \\ false)

  def externalize(
        code,
        %{"data" => "data:" <> encoded, "name" => name, "mime" => mime} = content,
        enforce_quota
      ) do
    with [_, base64] <- String.split(encoded, ";base64,", parts: 2),
         {:ok, data} <- Base.decode64(base64) do
      mime = if mime == "", do: "text/plain", else: mime

      id = identity(code, name, mime, data)
      if enforce_quota, do: ensure_capacity!(code, id, byte_size(data))

      content
      |> Map.delete("data")
      |> Map.merge(insert(code, id, name, mime, data, nil, nil))
    else
      _ -> content
    end
  end

  def externalize(_, content, _), do: content

  defp ensure_capacity!(code, id, bytes) do
    unless Repo.exists?(from(a in Attachment, where: a.id == ^id)) do
      used =
        Repo.one(
          from(a in Attachment,
            where: a.board_code == ^code,
            select: sum(a.size + fragment("coalesce(octet_length(?), 0)", a.preview))
          )
        ) || 0

      if used + bytes > Application.get_env(:nook, :attachment_max_bytes, 100_000_000),
        do: Repo.rollback(:storage_limit)
    end
  end

  defp insert(code, id, name, mime, data, preview, preview_mime) do
    Repo.insert!(
      %Attachment{
        id: id,
        board_code: code,
        name: name,
        mime: mime,
        size: byte_size(data),
        data: data,
        preview: preview,
        preview_mime: preview_mime
      },
      on_conflict: :nothing
    )

    %{"asset_id" => id, "name" => name, "mime" => mime, "size" => byte_size(data)}
  end

  defp identity(code, name, mime, data),
    do: :crypto.hash(:sha256, [code, 0, name, 0, mime, 0, data]) |> Base.encode16(case: :lower)

  defp valid_name?(name),
    do:
      is_binary(name) and String.valid?(name) and byte_size(name) in 1..255 and
        not String.contains?(name, ["\r", "\n", <<0>>])

  defp read_upload!(file, limit) do
    with {:ok, %{size: size}} when size > 0 and size <= limit <- File.stat(file.path),
         {:ok, data} <- File.read(file.path) do
      data
    else
      _ -> Repo.rollback(:file_limit)
    end
  end

  defp read_preview!(nil), do: {nil, nil}

  defp read_preview!(%Plug.Upload{} = file) do
    data = read_upload!(file, @max_preview)

    case {file.content_type, data} do
      {"image/png", <<137, 80, 78, 71, 13, 10, 26, 10, _::binary>>} -> {data, "image/png"}
      {"image/jpeg", <<255, 216, 255, _::binary>>} -> {data, "image/jpeg"}
      _ -> Repo.rollback(:invalid)
    end
  end

  defp read_preview!(_), do: Repo.rollback(:invalid)
end
