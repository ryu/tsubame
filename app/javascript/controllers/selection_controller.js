import { Controller } from "@hotwired/stimulus"
import { hatenaBookmarkUrl } from "lib/hatena_bookmark"
import { fetchWithCsrf, openInBackground } from "lib/fetch_helper"

const SCROLL_RATIO = 0.8

export default class extends Controller {
  static targets = ["feedList", "entryList", "entryDetail", "prevButton", "nextButton"]
  static values = {
    activeFeedIndex: { type: Number, default: -1 },
    activeEntryIndex: { type: Number, default: -1 }
  }

  connect() {
    this.markAllAbort = null

    this.boundHandleFrameLoad = this._handleFrameLoad.bind(this)
    this._entryListFrame()?.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)

    this.boundHandleFeedClick = this._handleFeedClick.bind(this)
    this.feedListTarget.addEventListener("click", this.boundHandleFeedClick)
  }

  disconnect() {
    this.markAllAbort?.abort()
    this._entryListFrame()?.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
    this.feedListTarget.removeEventListener("click", this.boundHandleFeedClick)
  }

  // Feed navigation

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

  // Entry navigation

  nextEntry() {
    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) return

    const newIndex = this.activeEntryIndexValue + 1
    if (newIndex < entryItems.length) {
      this.activeEntryIndexValue = newIndex
      this._activateEntry(newIndex)
    }
  }

  nextEntryOrFeed() {
    const entryItems = this._getEntryItems()
    const isLastEntry = this.activeEntryIndexValue >= entryItems.length - 1
    if (isLastEntry && this._hasNextUnreadFeed()) {
      this.nextFeed()
    } else {
      this.nextEntry()
    }
  }

  previousEntry() {
    const entryItems = this._getEntryItems()
    if (entryItems.length === 0 || this.activeEntryIndexValue <= 0) return

    const newIndex = this.activeEntryIndexValue - 1
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
    if (!externalLink || !externalLink.href) return

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
    if (this.activeFeedIndexValue < 0 || this.activeFeedIndexValue >= feedItems.length) return

    const activeFeed = feedItems[this.activeFeedIndexValue]
    const feedId = activeFeed.dataset.feedId
    if (!feedId) return

    this.markAllAbort?.abort()
    this.markAllAbort = new AbortController()
    fetchWithCsrf(`/feeds/${feedId}/mark_as_read`, {
      method: "POST",
      headers: { "Accept": "text/vnd.turbo-stream.html" },
      signal: this.markAllAbort.signal
    })
      .then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html))
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to mark all as read:", error)
        }
      })
  }

  reloadPage() {
    window.Turbo.visit(window.location.href, { action: "replace" })
  }

  get activeEntryIndex() {
    return this.activeEntryIndexValue
  }

  getActiveEntry() {
    const entryItems = this._getEntryItems()
    if (this.activeEntryIndexValue < 0 || this.activeEntryIndexValue >= entryItems.length) {
      return null
    }
    return entryItems[this.activeEntryIndexValue]
  }

  prevButtonTargetConnected() {
    this._updateNavButtons()
  }

  // Private

  _handleFeedClick(event) {
    const feedItem = event.target.closest(".feed-item")
    if (!feedItem) return
    const feedItems = this._getFeedItems()
    const index = feedItems.indexOf(feedItem)
    if (index >= 0) this.activeFeedIndexValue = index
  }

  _handleFrameLoad() {
    this.activeEntryIndexValue = -1
    this._syncActiveFeedIndexFromFrame()
    this._updateNavButtons()

    const frame = this._entryListFrame()
    const feedId = frame?.dataset.feedId
    if (feedId) {
      this.dispatch("feed-loaded", { detail: { feedId, isEmpty: this._getEntryItems().length === 0 } })
    }
  }

  _syncActiveFeedIndexFromFrame() {
    const frame = this._entryListFrame()
    const feedId = frame?.dataset.feedId
    if (!feedId) return

    const feedItems = this._getFeedItems()
    const index = feedItems.findIndex(item => item.dataset.feedId === feedId)
    if (index >= 0) {
      this.activeFeedIndexValue = index
      this._updateFeedActiveState()
    }
  }

  _activateFeed(index) {
    const feedItems = this._getFeedItems()
    if (index < 0 || index >= feedItems.length) return

    const feedItem = feedItems[index]
    this._updateFeedActiveState()

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

    if (entryItem.classList.contains("entry-unread")) {
      entryItem.classList.remove("entry-unread")
      entryItem.classList.add("entry-read")

      const feedItems = this._getFeedItems()
      const feedItem = feedItems[this.activeFeedIndexValue]
      this.dispatch("entry-read", { detail: { feedItem } })
    }

    const link = entryItem.matches("a") ? entryItem : entryItem.querySelector("a")
    if (link) link.click()

    this._scrollIntoViewIfNeeded(entryItem, this.entryListTarget)
    this.entryDetailTarget.scrollTo(0, 0)
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

  _updateNavButtons() {
    if (!this.hasPrevButtonTarget || !this.hasNextButtonTarget) return

    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) {
      this.prevButtonTarget.disabled = true
      this.nextButtonTarget.disabled = true
      return
    }

    this.prevButtonTarget.disabled = (this.activeEntryIndexValue <= 0)

    const isLastEntry = this.activeEntryIndexValue >= entryItems.length - 1
    const hasNextFeed = isLastEntry && this._hasNextUnreadFeed()
    this.nextButtonTarget.disabled = isLastEntry && !hasNextFeed

    this.nextButtonTarget.textContent = hasNextFeed
      ? "次のフィードへ ›"
      : "次のエントリ ›"
    this.nextButtonTarget.setAttribute("aria-label",
      hasNextFeed ? "次のフィードに移動" : "次のエントリに移動")
  }

  _hasNextUnreadFeed() {
    const feedItems = this._getFeedItems()
    for (let i = this.activeFeedIndexValue + 1; i < feedItems.length; i++) {
      if (feedItems[i].querySelector(".unread-badge")) return true
    }
    return false
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
