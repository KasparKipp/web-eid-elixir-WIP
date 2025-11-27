defmodule AppWeb.IdCardSignLive do
  use AppWeb, :live_view

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen gap-4 mx-auto max-w-7xl">
      <section :if={@uploaded_files != []} id="uploaded" class="bg-pink-400">
        <h2>Uploaded files</h2>
        <div :for={file <- @uploaded_files}>
          <p>File name {file[:name]}</p>
          <p>File key {file[:key]}</p>
        </div>
      </section>

      <form id="upload-form" phx-change="validate" phx-submit="save">
        <.live_file_input upload={@uploads.file_to_sign} accept=".txt" />
        <button type="submit">Upload</button>
      </form>

      <section
        phx-drop-target={@uploads.file_to_sign.ref}
        class="phx-drop-target-active:scale-105"
      >
        <div>Drop image here</div>
        <article :for={entry <- @uploads.file_to_sign.entries} class="upload-entry">
          <figure>
            <.live_img_preview entry={entry} />
            <figcaption>{entry.client_name}</figcaption>
          </figure>

          <progress value={entry.progress} max="100">{entry.progress}% </progress>

          <button
            type="button"
            phx-click="cancel-upload"
            phx-value-ref={entry.ref}
            aria-label="cancel"
          >
            &times;
          </button>

          <p :for={err <- upload_errors(@uploads.file_to_sign, entry)} class="alert alert-danger">
            {error_to_string(err)}
          </p>
        </article>

        <p :for={err <- upload_errors(@uploads.file_to_sign)} class="alert alert-danger">
          {error_to_string(err)}
        </p>
      </section>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(err), do: inspect(err)

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:uploaded_files, [])
      |> allow_upload(:file_to_sign,
        accept: ~w(.txt),
        max_entries: 2,
        external: &presign_upload/2
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    dbg(params)
    {:noreply, socket}
  end

  # File uploaded to s3 already
  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :file_to_sign, fn %{fields: fields}, entry ->
        {:ok, %{name: entry.client_name, key: fields["key"]}}
      end)

    dbg(uploaded_files)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file_to_sign, ref)}
  end

  # File uploaded
  @impl Phoenix.LiveView
  def handle_event(event, thing, socket) do
    dbg()
    {:noreply, socket}
  end

  defp presign_upload(entry, socket) do
    dbg(entry)
    # build key
    key = ["unsigned", "/", entry.client_name]

    %{url: url, fields: fields} = App.S3.presign_form("uploads", "#{key}")

    # reuse key from fields
    key =
      Enum.find(fields, fn
        {"key", _} -> true
        _ -> false
      end)
      |> elem(1)

    # What fields is
    # [
    #  {"key", "usigned/test.txt"},
    #  {"policy",
    #   "eyJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJ1cGxvYWRzIn0sWyJlcSIsIiRrZXkiLCJ1c2lnbmVkL3Rlc3QudHh0Il0seyJ4LWFtei1zZXJ2ZXItc2lkZS1lbmNyeXB0aW9uIjoiQUVTMjU2In0seyJ4LWFtei1jcmVkZW50aWFsIjoibWluaW9hZG1pbi8yMDI1MTEyNy91cy1lYXN0LTEvczMvYXdzNF9yZXF1ZXN0In0seyJ4LWFtei1hbGdvcml0aG0iOiJBV1M0LUhNQUMtU0hBMjU2In0seyJ4LWFtei1kYXRlIjoiMjAyNTExMjdUMjEyNTIyWiJ9XSwiZXhwaXJhdGlvbiI6IjIwMjUtMTEtMjdUMjE6MjU6MjIuMDAwWiJ9"},
    #  {"x-amz-algorithm", "AWS4-HMAC-SHA256"},
    #  {"x-amz-credential", "minioadmin/20251127/us-east-1/s3/aws4_request"},
    #  {"x-amz-date", "20251127T212522Z"},
    #  {"x-amz-server-side-encryption", "AES256"},
    #  {"x-amz-signature",
    #   "5f9ea784c3a40e6078e61458ff0d1431563fc79b9d4a0805ad695f88e7e6bc5c"}
    # ]

    # What https://gist.github.com/chrismccord/37862f1f8b1f5148644b75d20d1cb073 Chris McCord gist has
    # %{
    #  "key" => key,
    #  "acl" => "public-read",
    #  "content-type" => content_type,
    #  "x-amz-server-side-encryption" => "AES256",
    #  "x-amz-credential" => credential,
    #  "x-amz-algorithm" => "AWS4-HMAC-SHA256",
    #  "x-amz-date" => amz_date,
    #  "policy" => encoded_policy,
    #  "x-amz-signature" => signature(config, expires_at, encoded_policy)
    # }
    fields = Map.new(fields)

    dbg(key)
    meta = %{uploader: "S3", key: key, url: url, fields: fields}
    dbg(meta)
    {:ok, meta, socket}
  end
end
