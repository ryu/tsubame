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

  // Open all pinned entries in new tabs.
  // Pre-opens blank tabs immediately to preserve user activation (Safari 26+
  // requires window.open() in the trusted keydown handler's call stack).
  openPinned() {
    const pinCount = this._getPinCount()
    if (pinCount === 0) return

    // Pre-open blank tabs while user activation is still valid
    const preOpenedTabs = []
    for (let i = 0; i < pinCount; i++) {
      const tab = window.open("about:blank", "_blank")
      if (!tab) {
        // Popup blocker fired — close any already-opened tabs and abort
        preOpenedTabs.forEach(t => t.close())
        return
      }
      preOpenedTabs.push(tab)
    }
    window.focus()

    const abortController = new AbortController()
    fetchWithCsrf("/pinned_entry_open", {
      method: "POST",
      signal: abortController.signal
    })
      .then(response => response.json())
      .then(data => {
        if (data.urls.length === 0) {
          preOpenedTabs.forEach(tab => tab.close())
          return
        }

        // Navigate pre-opened tabs to actual URLs
        data.urls.forEach((url, i) => {
          if (preOpenedTabs[i]) {
            preOpenedTabs[i].location.href = url
          }
        })

        // Close extra tabs if fewer URLs than pre-opened
        for (let i = data.urls.length; i < preOpenedTabs.length; i++) {
          preOpenedTabs[i].close()
        }

        // All tabs navigated — now unpin
        return fetchWithCsrf("/pinned_entry_open", {
          method: "DELETE",
          body: JSON.stringify({ entry_ids: data.entry_ids }),
          signal: abortController.signal
        })
          .then(response => response.json())
          .then(unpinData => {
            data.entry_ids.forEach(id => this._removePinIcon(id))
            this._updatePinBadge(unpinData.pinned_count)
          })
      })
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to open pinned entries:", error)
          preOpenedTabs.forEach(tab => tab.close())
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

  _getPinCount() {
    const badge = document.querySelector("#pin_badge .pin-badge")
    return badge ? Math.min(parseInt(badge.textContent, 10) || 0, 5) : 0
  }

  _extractEntryId(entryItem) {
    const match = entryItem.id.match(/^entry_(\d+)$/)
    return match ? match[1] : null
  }

}
