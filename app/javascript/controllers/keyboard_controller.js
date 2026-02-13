import { Controller } from "@hotwired/stimulus"

// Minimal keydown router: filter IME/input, dispatch commands to other controllers
export default class extends Controller {
  // Command map: key → event name (dispatched with "keyboard:" prefix)
  static commandMap = {
    "j": "next-entry",
    "k": "previous-entry",
    "s": "next-feed",
    "a": "previous-feed",
    "A": "mark-all-as-read",  // Shift+A
    " ": "scroll-entry-detail-down",
    "SHIFT+ ": "scroll-entry-detail-up",
    "v": "open-entry-in-new-tab",
    "p": "toggle-pin",
    "o": "open-pinned",
    "r": "reload-page",
    "b": "open-hatena-bookmark",
    "h": "open-hatena-bookmark-add",
    "?": "toggle-help"
  }

  connect() {
    this.boundHandleKeydown = this._handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  // Private methods

  _handleKeydown(event) {
    // Skip keyboard shortcuts on mobile
    if (window.matchMedia("(max-width: 767px)").matches) return

    // Skip if IME is composing
    if (event.isComposing || event.keyCode === 229) return

    // Skip if focus is in input/textarea/select/contenteditable
    const activeElement = document.activeElement
    if (activeElement && (
      activeElement.tagName === "INPUT" ||
      activeElement.tagName === "TEXTAREA" ||
      activeElement.tagName === "SELECT" ||
      activeElement.isContentEditable
    )) return

    const command = this._lookupCommand(event)
    if (command) {
      event.preventDefault()
      this.dispatch(command, { prefix: "keyboard" })
    }
  }

  _lookupCommand(event) {
    const key = event.key
    const shiftKey = event.shiftKey

    // Special case: Shift+A
    if (key === "A" && shiftKey) {
      return this.constructor.commandMap["A"]
    }

    // Special case: Shift+Space
    if (key === " " && shiftKey) {
      return this.constructor.commandMap["SHIFT+ "]
    }

    // Regular keys
    return this.constructor.commandMap[key] || null
  }
}
