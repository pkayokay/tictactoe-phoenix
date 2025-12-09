// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket, Channel} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/tictactoe"
import topbar from "../vendor/topbar"

// Game Board Hook for Phoenix Channels
const gameBoardHook = {
  mounted() {
    const slug = this.el.dataset.slug
    const role = this.el.dataset.role
    
    if (!slug) return

    // Get CSRF token
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") || ""

    // Connect to socket (instance-based)
    this.gameSocket = new Socket("/socket", {params: {_csrf_token: csrfToken}})
    this.gameSocket.connect()

    // Join game channel
    this.gameChannel = this.gameSocket.channel(`game:${slug}`, {})
    
    this.gameChannel
      .join()
      .receive("ok", resp => {
        console.log("Joined game channel", resp)
        // Notify LiveView of connection
        this.pushEvent("channel_connected", {role: resp.role, game: resp.game})
      })
      .receive("error", resp => {
        console.error("Unable to join game channel", resp)
      })

    // Handle game updates
    this.gameChannel.on("game_updated", payload => {
      // Push update to LiveView
      this.pushEvent("game_updated", {game: payload.game})
    })

    // Handle move button clicks
    this.handleMoveClick = (e) => {
      if (e.target.matches("button[data-position]")) {
        const position = parseInt(e.target.getAttribute("data-position"))
        const currentRole = this.el.dataset.role
        const currentPlayer = this.el.dataset.currentPlayer
        const status = this.el.dataset.status

        // Only send move if it's the player's turn
        if (currentRole === currentPlayer && status === "playing" && !e.target.disabled) {
          this.gameChannel.push("move", {position: position})
            .receive("ok", resp => {
              console.log("Move successful", resp)
            })
            .receive("error", resp => {
              console.error("Move failed", resp)
            })
        }
      }
    }

    this.el.addEventListener("click", this.handleMoveClick)

    // Handle claim slot button clicks
    this.handleClaimSlotClick = (e) => {
      if (e.target.matches("button[phx-click='claim_slot']")) {
        const slot = e.target.getAttribute("phx-value-slot")
        if (slot && this.gameChannel) {
          this.gameChannel.push("claim_slot", {slot: slot})
            .receive("ok", resp => {
              console.log("Slot claimed successfully", resp)
              // Update role in LiveView
              this.pushEvent("channel_connected", {role: resp.role, game: resp.game})
            })
            .receive("error", resp => {
              console.error("Failed to claim slot", resp)
            })
        }
      }
    }

    // Listen for claim slot clicks on the entire page (since buttons are outside the hook element)
    document.addEventListener("click", this.handleClaimSlotClick)
  },

  updated() {
    // Update dataset when LiveView updates
    const role = this.el.getAttribute("data-role")
    const currentPlayer = this.el.getAttribute("data-current-player")
    const status = this.el.getAttribute("data-status")
    
    if (this.el.dataset.role !== role) {
      this.el.dataset.role = role
    }
    if (this.el.dataset.currentPlayer !== currentPlayer) {
      this.el.dataset.currentPlayer = currentPlayer
    }
    if (this.el.dataset.status !== status) {
      this.el.dataset.status = status
    }
  },

  destroyed() {
    if (this.handleMoveClick) {
      this.el.removeEventListener("click", this.handleMoveClick)
    }
    if (this.handleClaimSlotClick) {
      document.removeEventListener("click", this.handleClaimSlotClick)
    }
    if (this.gameChannel) {
      this.gameChannel.leave()
      this.gameChannel = null
    }
    if (this.gameSocket) {
      this.gameSocket.disconnect()
      this.gameSocket = null
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, GameBoard: gameBoardHook},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

