import { Controller } from "@hotwired/stimulus"

// Prev/next buttons rendered at the bottom of the entry detail pane on mobile.
export default class extends Controller {
  static targets = ["previous", "next"]
  static outlets = ["entry-list"]

  connect() {
    this.boundRefresh = this.refresh.bind(this)
    document.addEventListener("turbo:frame-load", this.boundRefresh)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundRefresh)
  }

  // The buttons are not parsed yet when connect() runs, so refresh once each
  // shows up rather than reading them there.
  previousTargetConnected() {
    this.refresh()
  }

  nextTargetConnected() {
    this.refresh()
  }

  entryListOutletConnected() {
    this.refresh()
  }

  previous() {
    if (this.hasEntryListOutlet) this.entryListOutlet.previous()
  }

  next() {
    if (this.hasEntryListOutlet) this.entryListOutlet.nextOrFeed()
  }

  refresh() {
    if (!this.hasPreviousTarget || !this.hasNextTarget || !this.hasEntryListOutlet) return

    const entries = this.entryListOutlet
    if (entries.items.length === 0) {
      this.previousTarget.disabled = true
      this.nextTarget.disabled = true
      return
    }

    this.previousTarget.disabled = entries.activeIndex <= 0

    const isLast = entries.activeIndex >= entries.items.length - 1
    const toNextFeed = isLast && entries.hasNextUnreadFeed
    this.nextTarget.disabled = isLast && !toNextFeed

    this.nextTarget.textContent = toNextFeed ? "次のフィードへ ›" : "次のエントリ ›"
    this.nextTarget.setAttribute("aria-label", toNextFeed ? "次のフィードに移動" : "次のエントリに移動")
  }
}
