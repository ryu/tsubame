import { Controller } from "@hotwired/stimulus"
import { fetchWithCsrf, openInBackground } from "lib/fetch_helper"

// Manages pin operations: toggle pin, open pinned entries
export default class extends Controller {
  static outlets = ["selection"]

  // Toggle pin for currently active entry
  togglePin() {
    if (!this.hasSelectionOutlet) return

    const entryItem = this.selectionOutlet.getActiveEntry()
    if (!entryItem) return

    const entryId = this._extractEntryId(entryItem)
    if (!entryId) return

    const abortController = new AbortController()
    fetchWithCsrf(`/entries/${entryId}/pin`, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html"
      },
      signal: abortController.signal
    })
      .then(response => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.text()
      })
      .then(html => {
        Turbo.renderStreamMessage(html)
        this._updateEntryListPinIcon(entryItem)
      })
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to toggle pin:", error)
        }
      })
  }

  // Open all pinned entries in new tabs
  openPinned() {
    const abortController = new AbortController()
    fetchWithCsrf("/pinned_entry_open", {
      method: "POST",
      signal: abortController.signal
    })
      .then(response => response.json())
      .then(data => {
        data.urls.forEach(url => openInBackground(url))
        data.entry_ids.forEach(id => this._removePinIcon(id))
        this._updatePinBadge(data.pinned_count)
      })
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to open pinned entries:", error)
        }
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

  _updatePinBadge(count) {
    const badge = document.getElementById("pin_badge")
    if (!badge) return

    badge.textContent = ""
    if (count > 0) {
      const span = document.createElement("span")
      span.className = "pin-badge"
      span.textContent = count
      badge.appendChild(span)
    }
  }

  _extractEntryId(entryItem) {
    const match = entryItem.id.match(/^entry_(\d+)$/)
    return match ? match[1] : null
  }

}
