import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["entry-detail", "entry-list", "pin"]

  static commandMap = {
    "j": "next-entry",
    "k": "previous-entry",
    "s": "next-feed",
    "a": "previous-feed",
    "A": "mark-all-as-read",
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

  static userActivationCommands = {
    "open-entry-in-new-tab": ["entryDetailOutlet", "openInNewTab"],
    "open-pinned": ["pinOutlet", "openPinned"],
    "open-hatena-bookmark": ["entryListOutlet", "openHatenaBookmark"],
    "open-hatena-bookmark-add": ["entryDetailOutlet", "openHatenaBookmarkAdd"]
  }

  connect() {
    this.boundHandleKeydown = this._handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  _handleKeydown(event) {
    if (window.matchMedia("(max-width: 767px)").matches) return

    if (event.isComposing || event.keyCode === 229) return

    const activeElement = document.activeElement
    if (activeElement && (
      activeElement.tagName === "INPUT" ||
      activeElement.tagName === "TEXTAREA" ||
      activeElement.tagName === "SELECT" ||
      activeElement.isContentEditable
    )) return

    const command = this._lookupCommand(event)
    if (!command) return

    event.preventDefault()

    const userActivationTarget = this.constructor.userActivationCommands[command]
    if (userActivationTarget) {
      const [outlet, method] = userActivationTarget
      this[outlet][method]()
      return
    }

    this.dispatch(command, { prefix: "keyboard" })
  }

  _lookupCommand(event) {
    const key = event.key
    const shiftKey = event.shiftKey

    if (key === "A" && shiftKey) {
      return this.constructor.commandMap["A"]
    }

    if (key === " " && shiftKey) {
      return this.constructor.commandMap["SHIFT+ "]
    }

    return this.constructor.commandMap[key] || null
  }
}
