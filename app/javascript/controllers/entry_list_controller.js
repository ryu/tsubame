import { Controller } from "@hotwired/stimulus"
import { hatenaBookmarkUrl } from "lib/hatena_bookmark"
import { openInBackground } from "lib/fetch_helper"
import { scrollIntoViewIfNeeded } from "lib/scroll"

// Selection and navigation of the entry list pane.
export default class extends Controller {
  static targets = ["list"]
  static outlets = ["feed-list"]

  frameLoad(event) {
    if (event.target.id !== "entry_list") return

    this.#markActive()

    const feedId = event.target.dataset.feedId
    if (feedId) {
      this.dispatch("loaded", { detail: { feedId, isEmpty: this.items.length === 0 } })
    }
  }

  next() {
    const index = this.activeIndex + 1
    if (index < this.items.length) this.#activate(index)
  }

  nextOrFeed() {
    const isLast = this.activeIndex >= this.items.length - 1
    if (isLast && this.hasNextUnreadFeed) {
      this.feedListOutlet.next()
    } else {
      this.next()
    }
  }

  previous() {
    if (this.activeIndex > 0) this.#activate(this.activeIndex - 1)
  }

  openHatenaBookmark() {
    const item = this.activeItem
    if (!item) return

    const url = item.querySelector(".hatena-count-clickable")?.dataset.url || item.dataset.entryUrl
    const bookmarkUrl = url && hatenaBookmarkUrl(url)
    if (bookmarkUrl) openInBackground(bookmarkUrl)
  }

  // Read through the entry-list outlet by pin and entry-nav

  get items() {
    if (!this.hasListTarget) return []
    return Array.from(this.listTarget.querySelectorAll(".entry-item"))
  }

  get activeItem() {
    return this.items[this.activeIndex] || null
  }

  // Derived from the selected entry, never stored. A frame load swaps the list
  // out from under a stored index, and turbo:frame-load arrives after the entries
  // are already in the DOM — late enough for the next keypress to read a stale
  // cursor and either move nowhere or lose the selection.
  get activeIndex() {
    return this.activeId ? this.items.findIndex(item => item.id === this.activeId) : -1
  }

  get hasNextUnreadFeed() {
    return this.hasFeedListOutlet && this.feedListOutlet.hasNextUnread
  }

  // Private

  #activate(index) {
    const item = this.items[index]
    if (!item) return

    this.activeId = item.id
    this.#markActive()
    this.#markRead(item)

    const link = item.matches("a") ? item : item.querySelector("a")
    if (link) link.click()

    scrollIntoViewIfNeeded(item, this.listTarget)
    this.dispatch("moved")
  }

  #markRead(item) {
    if (!item.classList.contains("entry-unread")) return

    item.classList.remove("entry-unread")
    item.classList.add("entry-read")
    this.dispatch("read", { detail: { feedItem: this.hasFeedListOutlet ? this.feedListOutlet.activeItem : null } })
  }

  #markActive() {
    this.items.forEach(item => {
      if (item.id === this.activeId) {
        item.dataset.active = "true"
        item.setAttribute("aria-current", "true")
      } else {
        delete item.dataset.active
        item.removeAttribute("aria-current")
      }
    })
  }
}
