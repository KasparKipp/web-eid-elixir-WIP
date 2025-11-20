// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "deps/phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "deps/phoenix";
import { type HooksOptions, LiveSocket } from "deps/phoenix_live_view";
// import { hooks as colocatedHooks } from "phoenix-colocated/app";
import { authenticate } from "@web-eid/web-eid-library/dist/es/web-eid";

import topbar from "topbar";

const colocatedHooks: HooksOptions = {};

const csrfToken = document
  ?.querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

const ErrorCode = {
  ERR_WEBEID_ACTION_TIMEOUT: "ERR_WEBEID_ACTION_TIMEOUT",
  ERR_WEBEID_USER_TIMEOUT: "ERR_WEBEID_USER_TIMEOUT",
  ERR_WEBEID_VERSION_MISMATCH: "ERR_WEBEID_VERSION_MISMATCH",
  ERR_WEBEID_VERSION_INVALID: "ERR_WEBEID_VERSION_INVALID",
  ERR_WEBEID_EXTENSION_UNAVAILABLE: "ERR_WEBEID_EXTENSION_UNAVAILABLE",
  ERR_WEBEID_NATIVE_UNAVAILABLE: "ERR_WEBEID_NATIVE_UNAVAILABLE",
  ERR_WEBEID_UNKNOWN_ERROR: "ERR_WEBEID_UNKNOWN_ERROR",
  ERR_WEBEID_CONTEXT_INSECURE: "ERR_WEBEID_CONTEXT_INSECURE",
  ERR_WEBEID_USER_CANCELLED: "ERR_WEBEID_USER_CANCELLED",
  ERR_WEBEID_NATIVE_INVALID_ARGUMENT: "ERR_WEBEID_NATIVE_INVALID_ARGUMENT",
  ERR_WEBEID_NATIVE_FATAL: "ERR_WEBEID_NATIVE_FATAL",
  ERR_WEBEID_ACTION_PENDING: "ERR_WEBEID_ACTION_PENDING",
  ERR_WEBEID_MISSING_PARAMETER: "ERR_WEBEID_MISSING_PARAMETER",
} as const;

const Hooks: HooksOptions = {};

Hooks.WebEidAuth = {
  mounted() {
    const lang = navigator.language.substr(0, 2);

    this.el.addEventListener("click", async () => {
      try {
        console.log("Clicked. Lang:", lang);

        // 1️⃣ Request challenge nonce from server via LiveView
        const response = await this.pushEvent("get_nonce", {});
        const nonce = response.nonce;
        console.log("Received nonce:", nonce);

        // 2️⃣ Authenticate using Web eID JS library
        const authToken = await authenticate(nonce, { lang });
        console.log("Web eID auth token:", authToken);

        // 3️⃣ Send authentication token to server
        const authenticationResponse = await this.pushEvent("authenticate", {
          authToken,
        });
        if (!authenticationResponse.ok) {
          alert("Unexpected problem occurred");
        }
      } catch (error) {
        if (error.code === ErrorCode.ERR_WEBEID_EXTENSION_UNAVAILABLE) {
          alert("Web eID extension not available");
        }
        console.log("Error code:", error?.code);
        console.error("Authentication failed! Error:", error);
      }
    });
  },
};

Hooks.TimeAgo = {
  mounted() {
    this.updateTime();
    this.interval = setInterval(() => this.updateTime(), 1000);
  },

  updated() {
    this.updateTime();
  },

  destroyed() {
    if (this.interval) {
      clearInterval(this.interval);
    }
  },

  updateTime() {
    const el = this.el;
    const timestamp = el.dataset.timestamp;
    if (!timestamp) {
      return;
    }

    const diff = Math.floor(
      (Date.now() - new Date(timestamp).getTime()) / 1000
    );

    if (diff < 0) {
      el.textContent = "in the future";
      return;
    }

    if (diff <= 5) {
      el.textContent = "just now";
      return;
    }

    el.textContent = `${diff} seconds ago`;
  },
};
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, ...Hooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true
      );

      window.liveReloader = reloader;
    }
  );
}
