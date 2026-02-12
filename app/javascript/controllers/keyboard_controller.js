import { Controller } from "@hotwired/stimulus"
import { openHatenaBookmarkPage } from "lib/hatena_bookmark"

export default class extends Controller {
  static targets = ["feedList", "entryList", "entryDetail", "helpDialog"]
  static values = {
    activeFeedIndex: { type: Number, default: -1 },
    activeEntryIndex: { type: Number, default: -1 }
  }

  connect() {
    this.abortController = new AbortController()
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    this.boundHandleKeydown = this._handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)

    // Listen for Turbo Frame updates to reset entry index
    this.boundHandleFrameLoad = this._handleFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)

    this._restoreActiveStates()
  }

  disconnect() {
    this.abortController.abort()
    document.removeEventListener("keydown", this.boundHandleKeydown)
    document.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
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

    // Help dialog toggle (handles both open and closed state)
    if (event.key === "?") {
      event.preventDefault()
      this._toggleHelpDialog()
      return
    }

    // Skip all other shortcuts when help dialog is open
    if (this.hasHelpDialogTarget && this.helpDialogTarget.open) return

    const key = event.key
    const shiftKey = event.shiftKey

    switch (key) {
      case "j":
        event.preventDefault()
        this._nextEntry()
        break
      case "k":
        event.preventDefault()
        this._previousEntry()
        break
      case "s":
        event.preventDefault()
        this._nextFeed()
        break
      case "A":
        // Shift+A: Mark all entries in current feed as read
        if (shiftKey) {
          event.preventDefault()
          this._markAllAsRead()
        }
        break
      case "a":
        event.preventDefault()
        this._previousFeed()
        break
      case " ":
        event.preventDefault()
        if (shiftKey) {
          this._scrollEntryDetail(-1)
        } else {
          this._scrollEntryDetail(1)
        }
        break
      case "v":
        event.preventDefault()
        this._openCurrentEntryInNewTab()
        break
      case "p":
        event.preventDefault()
        this._toggleCurrentEntryPin()
        break
      case "o":
        event.preventDefault()
        this._openPinnedEntries()
        break
      case "r":
        event.preventDefault()
        this._reloadPage()
        break
      case "b":
        event.preventDefault()
        this._openCurrentEntryHatenaBookmark()
        break
      case "h":
        event.preventDefault()
        this._openCurrentEntryHatenaBookmarkAdd()
        break
    }
  }

  _handleFrameLoad(event) {
    // Reset entry index when entry_list frame is updated
    if (event.target.id === "entry_list") {
      this.activeEntryIndexValue = -1
      // Auto-select first entry if available
      const entryItems = this._getEntryItems()
      if (entryItems.length > 0) {
        this.activeEntryIndexValue = 0
        this._activateEntry(0)
      }
    }
  }

  _restoreActiveStates() {
    // Restore visual active state on page load/reconnect
    if (this.activeFeedIndexValue >= 0) {
      this._updateFeedActiveState()
    }
    if (this.activeEntryIndexValue >= 0) {
      this._updateEntryActiveState()
    }
  }

  // Feed navigation

  _nextFeed() {
    const feedItems = this._getFeedItems()
    if (feedItems.length === 0) return

    const newIndex = Math.min(this.activeFeedIndexValue + 1, feedItems.length - 1)
    this.activeFeedIndexValue = newIndex
    this._activateFeed(newIndex)
  }

  _previousFeed() {
    const feedItems = this._getFeedItems()
    if (feedItems.length === 0) return

    const newIndex = Math.max(this.activeFeedIndexValue - 1, 0)
    this.activeFeedIndexValue = newIndex
    this._activateFeed(newIndex)
  }

  _activateFeed(index) {
    const feedItems = this._getFeedItems()
    if (index < 0 || index >= feedItems.length) return

    const feedItem = feedItems[index]
    this._updateFeedActiveState()

    // Click the feed link to load entries via Turbo Frame
    feedItem.click()
    this._scrollIntoViewIfNeeded(feedItem, this.feedListTarget)
  }

  _updateFeedActiveState() {
    const feedItems = this._getFeedItems()
    feedItems.forEach((item, i) => {
      if (i === this.activeFeedIndexValue) {
        item.dataset.active = "true"
        item.setAttribute("aria-current", "true")
      } else {
        delete item.dataset.active
        item.removeAttribute("aria-current")
      }
    })
  }

  _getFeedItems() {
    if (!this.hasFeedListTarget) return []
    return Array.from(this.feedListTarget.querySelectorAll(".feed-item"))
  }

  // Entry navigation

  _nextEntry() {
    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) return

    const newIndex = Math.min(this.activeEntryIndexValue + 1, entryItems.length - 1)
    this.activeEntryIndexValue = newIndex
    this._activateEntry(newIndex)
  }

  _previousEntry() {
    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) return

    const newIndex = Math.max(this.activeEntryIndexValue - 1, 0)
    this.activeEntryIndexValue = newIndex
    this._activateEntry(newIndex)
  }

  _activateEntry(index) {
    const entryItems = this._getEntryItems()
    if (index < 0 || index >= entryItems.length) return

    const entryItem = entryItems[index]
    this._updateEntryActiveState()

    // Optimistically mark as read in UI
    // (EntriesController#show handles server-side mark_as_read)
    if (entryItem.classList.contains("entry-unread")) {
      entryItem.classList.remove("entry-unread")
      entryItem.classList.add("entry-read")
      this._decrementUnreadBadge()
    }

    // Click the entry link to load detail via Turbo Frame
    entryItem.click()
    this._scrollIntoViewIfNeeded(entryItem, this.entryListTarget)
  }

  _updateEntryActiveState() {
    const entryItems = this._getEntryItems()
    entryItems.forEach((item, i) => {
      if (i === this.activeEntryIndexValue) {
        item.dataset.active = "true"
        item.setAttribute("aria-current", "true")
      } else {
        delete item.dataset.active
        item.removeAttribute("aria-current")
      }
    })
  }

  _getEntryItems() {
    if (!this.hasEntryListTarget) return []
    return Array.from(this.entryListTarget.querySelectorAll(".entry-item"))
  }

  _decrementUnreadBadge() {
    const activeFeedItems = this._getFeedItems()
    if (this.activeFeedIndexValue < 0 || this.activeFeedIndexValue >= activeFeedItems.length) return

    const activeFeed = activeFeedItems[this.activeFeedIndexValue]
    const badge = activeFeed.querySelector(".unread-badge")
    if (!badge) return

    const currentCount = parseInt(badge.textContent, 10)
    if (currentCount > 1) {
      badge.textContent = currentCount - 1
    } else {
      badge.remove()
    }
  }

  // Entry detail actions

  _scrollEntryDetail(direction) {
    if (!this.hasEntryDetailTarget) return

    const scrollAmount = this.entryDetailTarget.clientHeight * 0.8
    this.entryDetailTarget.scrollBy({
      top: scrollAmount * direction,
      behavior: "smooth"
    })
  }

  _openCurrentEntryInNewTab() {
    if (!this.hasEntryDetailTarget) return

    const externalLink = this.entryDetailTarget.querySelector(".external-link")
    if (!externalLink || !externalLink.href) {
      console.warn("No external link found for current entry")
      return
    }

    window.open(externalLink.href, "_blank")
  }

  _toggleCurrentEntryPin() {
    const entryItems = this._getEntryItems()
    if (this.activeEntryIndexValue < 0 || this.activeEntryIndexValue >= entryItems.length) return

    const entryItem = entryItems[this.activeEntryIndexValue]
    const entryId = this._extractEntryId(entryItem)
    if (!entryId || !this.csrfToken) return

    fetch(`/entries/${entryId}/toggle_pin`, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        "Accept": "text/vnd.turbo-stream.html",
        "Content-Type": "application/json"
      },
      signal: this.abortController.signal
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

  _openCurrentEntryHatenaBookmark() {
    const entryItems = this._getEntryItems()
    if (this.activeEntryIndexValue < 0 || this.activeEntryIndexValue >= entryItems.length) return

    const entryItem = entryItems[this.activeEntryIndexValue]
    const countSpan = entryItem.querySelector(".hatena-count-clickable")
    const url = (countSpan && countSpan.dataset.url) || entryItem.dataset.entryUrl
    if (!url) return

    openHatenaBookmarkPage(url)
  }

  _openCurrentEntryHatenaBookmarkAdd() {
    if (!this.hasEntryDetailTarget) return

    const hatenaLink = this.entryDetailTarget.querySelector(".hatena-add-link")
    if (!hatenaLink) return

    window.open(hatenaLink.href, "_blank", "noopener,noreferrer")
  }

  _markAllAsRead() {
    const feedItems = this._getFeedItems()
    if (this.activeFeedIndexValue < 0 || this.activeFeedIndexValue >= feedItems.length) {
      console.warn("No active feed selected")
      return
    }

    const activeFeed = feedItems[this.activeFeedIndexValue]
    const feedId = activeFeed.dataset.feedId
    if (!feedId || !this.csrfToken) {
      console.warn("Feed ID or CSRF token not found")
      return
    }

    fetch(`/feeds/${feedId}/mark_as_read`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        "Accept": "application/json",
        "Content-Type": "application/json"
      },
      signal: this.abortController.signal
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          // Reload page to update unread badges in left pane
          window.Turbo.visit(window.location.href, { action: "replace" })
        }
      })
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to mark all as read:", error)
        }
      })
  }

  _openPinnedEntries() {
    if (!this.csrfToken) return

    fetch("/entries/open_pinned", {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.csrfToken,
        "Accept": "application/json",
        "Content-Type": "application/json"
      },
      signal: this.abortController.signal
    })
      .then(response => response.json())
      .then(data => {
        data.urls.forEach(url => window.open(url, "_blank"))
        data.entry_ids.forEach(id => this._removePinIcon(id))
        this._updatePinBadge(data.pinned_count)
      })
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to open pinned entries:", error)
        }
      })
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

  _reloadPage() {
    window.Turbo.visit(window.location.href, { action: "replace" })
  }

  // Help dialog

  closeHelpDialog() {
    if (this.hasHelpDialogTarget && this.helpDialogTarget.open) {
      this.helpDialogTarget.close()
    }
  }

  _toggleHelpDialog() {
    if (!this.hasHelpDialogTarget) return
    if (this.helpDialogTarget.open) {
      this.helpDialogTarget.close()
    } else {
      this.helpDialogTarget.showModal()
    }
  }

  // Utilities

  _extractEntryId(entryItem) {
    const match = entryItem.id.match(/^entry_(\d+)$/)
    return match ? match[1] : null
  }

  _scrollIntoViewIfNeeded(element, container) {
    const elementRect = element.getBoundingClientRect()
    const containerRect = container.getBoundingClientRect()

    if (elementRect.top < containerRect.top) {
      element.scrollIntoView({ block: "start", behavior: "smooth" })
    } else if (elementRect.bottom > containerRect.bottom) {
      element.scrollIntoView({ block: "end", behavior: "smooth" })
    }
  }
}
