defmodule NookWeb.AttachmentController do
  use NookWeb, :controller

  def create(conn, %{"code" => code, "file" => %Plug.Upload{} = file} = params) do
    case Nook.Attachments.upload(code, actor(conn), file, params["preview"]) do
      {:ok, reference} ->
        json(conn, reference)

      {:error, reason} when reason in [:file_limit, :storage_limit, :invalid] ->
        message =
          case reason do
            :file_limit -> "Choose a nonempty file up to 10 MB."
            :storage_limit -> "This board's file storage is full (100 MB)."
            :invalid -> "Choose an image, PDF, text, Markdown, or CSV file."
          end

        conn |> put_status(422) |> json(%{error: message})

      _ ->
        conn |> put_status(404) |> json(%{error: "Board unavailable"})
    end
  end

  def create(conn, _), do: conn |> put_status(422) |> json(%{error: "Choose a file to upload."})

  def show(conn, %{"code" => code, "id" => id} = params) do
    download = params["download"] == "1"

    case Nook.Attachments.fetch(code, id, actor(conn), download) do
      {:ok, asset} ->
        conn =
          conn
          |> put_resp_header("cache-control", "private, no-store")
          |> put_resp_header("x-content-type-options", "nosniff")
          |> put_resp_header("content-security-policy", "default-src 'none'; sandbox")
          |> put_resp_content_type(asset.mime)

        conn =
          if download,
            do:
              put_resp_header(
                conn,
                "content-disposition",
                "attachment; filename*=UTF-8''#{URI.encode(asset.name, &URI.char_unreserved?/1)}"
              ),
            else: conn

        send_resp(conn, 200, asset.data)

      _ ->
        send_resp(conn, 404, "File unavailable")
    end
  end

  defp actor(conn), do: Nook.Access.from_session(get_session(conn))
end
