import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
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
    "open-entry-in-new-tab": ["entry-detail", "openInNewTab"],
    "open-pinned": ["pin", "openPinned"],
    "open-hatena-bookmark": ["entry-list", "openHatenaBookmark"],
    "open-hatena-bookmark-add": ["entry-detail", "openHatenaBookmarkAdd"]
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

    if (this.constructor.userActivationCommands[command]) {
      this._directInvoke(command)
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

  _directInvoke(command) {
    const target = this.constructor.userActivationCommands[command]
    if (!target) return false

    const [controllerName, method] = target
    const controller = this.application.getControllerForElementAndIdentifier(this.element, controllerName)
    if (controller && typeof controller[method] === "function") {
      controller[method]()
      return true
    }
    return false
  }
}
