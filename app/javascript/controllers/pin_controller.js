import { Controller } from "@hotwired/stimulus"
import { submitTurboStream } from "lib/fetch_helper"

// Manages pin operations: toggle pin, open pinned entries
export default class extends Controller {
  static outlets = ["entry-list"]

  // Toggle pin for currently active entry
  togglePin() {
    if (!this.hasEntryListOutlet) return

    const entryItem = this.entryListOutlet.activeItem
    if (!entryItem) return

    const entryId = this._extractEntryId(entryItem)
    if (!entryId) return

    const pinned = !!entryItem.querySelector(".pin-icon")
    submitTurboStream(`/entries/${entryId}/pin`, { method: pinned ? "DELETE" : "POST" })
      .then(() => this._updateEntryListPinIcon(entryItem))
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to toggle pin:", error)
        }
      })
  }

  // Open all pinned entries in new tabs, then unpin only the ones that opened.
  // URLs are pre-rendered into #pin_badge data attributes so window.open can
  // be called synchronously with real URLs (Safari blocks empty-URL popups).
  openPinned() {
    const badge = document.getElementById("pin_badge")
    if (!badge) return

    const urls = JSON.parse(badge.dataset.pinUrls || "[]")
    const entryIds = JSON.parse(badge.dataset.pinEntryIds || "[]")
    if (urls.length === 0) return

    const openedEntryIds = []
    urls.forEach((url, i) => {
      const w = window.open(url, "_blank")
      if (w) openedEntryIds.push(entryIds[i])
      else console.warn(`[pin.openPinned] window.open blocked for url: ${url}`)
    })
    window.focus()

    if (openedEntryIds.length === 0) {
      console.warn("[pin.openPinned] no tabs opened, skipping unpin")
      return
    }

    submitTurboStream("/pinned_entry_open", {
      method: "DELETE",
      body: JSON.stringify({ entry_ids: openedEntryIds })
    })
      .then(() => openedEntryIds.forEach(id => this._removePinIcon(id)))
      .catch(error => {
        console.warn("Failed to unpin opened entries:", error)
      })
  }

  // Private methods

  _updateEntryListPinIcon(entryItem) {
    const titleRow = entryItem.querySelector(".entry-title-row")
    if (!titleRow) return

    const pinIcon = titleRow.querySelector(".pin-icon")

    if (pinIcon) {
      pinIcon.remove()
    } else {
      const icon = document.createElement("span")
      icon.className = "pin-icon"
      icon.textContent = "📌"
      titleRow.insertBefore(icon, titleRow.firstChild)
    }
  }

  _removePinIcon(entryId) {
    const entryItem = document.getElementById(`entry_${entryId}`)
    if (!entryItem) return

    const pinIcon = entryItem.querySelector(".pin-icon")
    if (pinIcon) pinIcon.remove()
  }

  _extractEntryId(entryItem) {
    const match = entryItem.id.match(/^entry_(\d+)$/)
    return match ? match[1] : null
  }

}
