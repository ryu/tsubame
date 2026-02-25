import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]

  connect() {
    this._keydownHandler = this.#handleKeydown.bind(this)
  }

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.#addOutsideClickListener()
    document.addEventListener("keydown", this._keydownHandler)
    this.menuTarget.querySelector("a")?.focus()
  }

  close({ returnFocus = true } = {}) {
    if (this.menuTarget.hidden) return
    this.menuTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.#cleanup()
    if (returnFocus) this.toggleTarget.focus()
  }

  disconnect() {
    this.#cleanup()
  }

  #handleOutsideClick = (event) => {
    if (!this.element.contains(event.target)) {
      this.close({ returnFocus: false })
    }
  }

  #handleKeydown(event) {
    if (event.key === "Escape") {
      event.stopPropagation()
      this.close()
    }
  }

  #addOutsideClickListener() {
    document.addEventListener("click", this.#handleOutsideClick)
  }

  #cleanup() {
    document.removeEventListener("click", this.#handleOutsideClick)
    document.removeEventListener("keydown", this._keydownHandler)
  }
}
