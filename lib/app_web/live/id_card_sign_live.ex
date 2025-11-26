defmodule AppWeb.IdCardSignLive do
  use AppWeb, :live_view

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen gap-4 mx-auto max-w-7xl">
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
      |> allow_upload(:file_to_sign, accept: ~w(.txt), max_entries: 2)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", params, socket) do
    dbg(params)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    dbg(socket)

    uploaded_files =
      consume_uploaded_entries(socket, :file_to_sign, fn %{path: path}, entry ->
        dest = Path.join(Application.app_dir(:app, "priv/static/uploads"), entry.client_name)
        # You will need to create `priv/static/uploads` for `File.cp!/2` to work.
        dbg(path)
        dbg(dest)
        File.cp!(path, dest)
        {:ok, ~p"/uploads/#{Path.basename(dest)}"}
      end)

    dbg(uploaded_files)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file_to_sign, ref)}
  end
end
