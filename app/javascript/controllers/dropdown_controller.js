import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.#handleOutsideClick)
    document.addEventListener("keydown", this.#handleKeydown)
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

  #handleKeydown = (event) => {
    if (event.key === "Escape") {
      event.stopPropagation()
      this.close()
    }
  }

  #cleanup() {
    document.removeEventListener("click", this.#handleOutsideClick)
    document.removeEventListener("keydown", this.#handleKeydown)
  }
}
