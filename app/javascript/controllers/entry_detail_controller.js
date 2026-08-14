import { Controller } from "@hotwired/stimulus"
import { openInBackground } from "lib/fetch_helper"

const SCROLL_RATIO = 0.8

// Reading actions for the entry detail pane.
export default class extends Controller {
  static targets = ["pane"]

  scrollDown() {
    this.#scroll(1)
  }

  scrollUp() {
    this.#scroll(-1)
  }

  resetScroll() {
    if (this.hasPaneTarget) this.paneTarget.scrollTo(0, 0)
  }

  openInNewTab() {
    this.#openLink(".external-link")
  }

  openHatenaBookmarkAdd() {
    this.#openLink(".hatena-add-link")
  }

  // Private

  #openLink(selector) {
    if (!this.hasPaneTarget) return

    const link = this.paneTarget.querySelector(selector)
    if (link?.href) openInBackground(link.href)
  }

  #scroll(direction) {
    if (!this.hasPaneTarget) return

    this.paneTarget.scrollBy({
      top: this.paneTarget.clientHeight * SCROLL_RATIO * direction,
      behavior: "smooth"
    })
  }
}
