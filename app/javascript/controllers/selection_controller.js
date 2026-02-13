import { Controller } from "@hotwired/stimulus"
import { hatenaBookmarkUrl } from "lib/hatena_bookmark"
import { fetchWithCsrf, openInBackground } from "lib/fetch_helper"

const SCROLL_RATIO = 0.8

// Manages feed/entry navigation, active state, and entry actions
export default class extends Controller {
  static targets = ["feedList", "entryList", "entryDetail"]
  static values = {
    activeFeedIndex: { type: Number, default: -1 },
    activeEntryIndex: { type: Number, default: -1 }
  }

  connect() {
    this.markAllAbort = null

    this.boundHandleFrameLoad = this._handleFrameLoad.bind(this)
    this._entryListFrame()?.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)
  }

  disconnect() {
    this.markAllAbort?.abort()
    this._entryListFrame()?.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
  }

  // Feed navigation actions

  nextFeed() {
    const feedItems = this._getFeedItems()
    if (feedItems.length === 0) return

    const newIndex = Math.min(this.activeFeedIndexValue + 1, feedItems.length - 1)
    this.activeFeedIndexValue = newIndex
    this._activateFeed(newIndex)
  }

  previousFeed() {
    const feedItems = this._getFeedItems()
    if (feedItems.length === 0) return

    const newIndex = Math.max(this.activeFeedIndexValue - 1, 0)
    this.activeFeedIndexValue = newIndex
    this._activateFeed(newIndex)
  }

  // Entry navigation actions

  nextEntry() {
    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) return

    const newIndex = Math.min(this.activeEntryIndexValue + 1, entryItems.length - 1)
    this.activeEntryIndexValue = newIndex
    this._activateEntry(newIndex)
  }

  previousEntry() {
    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) return

    const newIndex = Math.max(this.activeEntryIndexValue - 1, 0)
    this.activeEntryIndexValue = newIndex
    this._activateEntry(newIndex)
  }

  // Entry detail actions

  scrollEntryDetailDown() {
    this._scrollEntryDetail(1)
  }

  scrollEntryDetailUp() {
    this._scrollEntryDetail(-1)
  }

  openEntryInNewTab() {
    if (!this.hasEntryDetailTarget) return

    const externalLink = this.entryDetailTarget.querySelector(".external-link")
    if (!externalLink || !externalLink.href) {
      console.warn("No external link found for current entry")
      return
    }

    openInBackground(externalLink.href)
  }

  openHatenaBookmark() {
    const entryItems = this._getEntryItems()
    if (this.activeEntryIndexValue < 0 || this.activeEntryIndexValue >= entryItems.length) return

    const entryItem = entryItems[this.activeEntryIndexValue]
    const countSpan = entryItem.querySelector(".hatena-count-clickable")
    const url = (countSpan && countSpan.dataset.url) || entryItem.dataset.entryUrl
    if (!url) return

    const bookmarkUrl = hatenaBookmarkUrl(url)
    if (bookmarkUrl) openInBackground(bookmarkUrl)
  }

  openHatenaBookmarkAdd() {
    if (!this.hasEntryDetailTarget) return

    const hatenaLink = this.entryDetailTarget.querySelector(".hatena-add-link")
    if (!hatenaLink) return

    openInBackground(hatenaLink.href)
  }

  markAllAsRead() {
    const feedItems = this._getFeedItems()
    if (this.activeFeedIndexValue < 0 || this.activeFeedIndexValue >= feedItems.length) {
      console.warn("No active feed selected")
      return
    }

    const activeFeed = feedItems[this.activeFeedIndexValue]
    const feedId = activeFeed.dataset.feedId
    if (!feedId) {
      console.warn("Feed ID not found")
      return
    }

    this.markAllAbort?.abort()
    this.markAllAbort = new AbortController()
    fetchWithCsrf(`/feeds/${feedId}/mark_as_read`, {
      method: "POST",
      signal: this.markAllAbort.signal
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

  reloadPage() {
    window.Turbo.visit(window.location.href, { action: "replace" })
  }

  // Public getter for activeEntryIndexValue (used by pin_controller via outlets)
  get activeEntryIndex() {
    return this.activeEntryIndexValue
  }

  // Public getter for active entry element (used by pin_controller)
  getActiveEntry() {
    const entryItems = this._getEntryItems()
    if (this.activeEntryIndexValue < 0 || this.activeEntryIndexValue >= entryItems.length) {
      return null
    }
    return entryItems[this.activeEntryIndexValue]
  }

  // Private methods

  _handleFrameLoad() {
    this.activeEntryIndexValue = -1
    // Auto-select first entry if available
    const entryItems = this._getEntryItems()
    if (entryItems.length > 0) {
      this.activeEntryIndexValue = 0
      this._activateEntry(0)
    }
  }

  _activateFeed(index) {
    const feedItems = this._getFeedItems()
    if (index < 0 || index >= feedItems.length) return

    const feedItem = feedItems[index]
    this._updateFeedActiveState()

    // Click the feed link to load entries via Turbo Frame
    const link = feedItem.matches("a") ? feedItem : feedItem.querySelector("a")
    if (link) link.click()

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
    const link = entryItem.matches("a") ? entryItem : entryItem.querySelector("a")
    if (link) link.click()

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

  _scrollEntryDetail(direction) {
    if (!this.hasEntryDetailTarget) return

    const scrollAmount = this.entryDetailTarget.clientHeight * SCROLL_RATIO
    this.entryDetailTarget.scrollBy({
      top: scrollAmount * direction,
      behavior: "smooth"
    })
  }

  _entryListFrame() {
    if (!this.hasEntryListTarget) return null
    return this.entryListTarget.querySelector("turbo-frame#entry_list")
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
