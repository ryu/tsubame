import { Controller } from "@hotwired/stimulus"
import { submitTurboStream } from "lib/fetch_helper"
import { scrollIntoViewIfNeeded } from "lib/scroll"

// Selection and navigation of the feed pane.
export default class extends Controller {
  static targets = ["list"]

  disconnect() {
    this.markAllAbort?.abort()
  }

  frameLoad(event) {
    if (event.target.id !== "entry_list") return

    const feedId = event.target.dataset.feedId
    if (!feedId) return

    this.activeId = feedId
    this.#markActive()
  }

  click(event) {
    const item = event.target.closest(".feed-item")
    if (item) this.activeId = item.dataset.feedId
  }

  next() {
    if (this.items.length > 0) this.#activate(Math.min(this.activeIndex + 1, this.items.length - 1))
  }

  previous() {
    if (this.items.length > 0) this.#activate(Math.max(this.activeIndex - 1, 0))
  }

  markAllAsRead() {
    const feedId = this.activeItem?.dataset.feedId
    if (!feedId) return

    this.markAllAbort?.abort()
    this.markAllAbort = new AbortController()
    submitTurboStream(`/feeds/${feedId}/mark_as_read`, { signal: this.markAllAbort.signal })
      .catch(error => {
        if (error.name !== "AbortError") console.warn("Failed to mark all as read:", error)
      })
  }

  // Read through the feed-list outlet by entry-list

  get items() {
    if (!this.hasListTarget) return []
    return Array.from(this.listTarget.querySelectorAll(".feed-item"))
  }

  get activeItem() {
    return this.items[this.activeIndex] || null
  }

  get hasNextUnread() {
    return this.items.slice(this.activeIndex + 1).some(item => item.querySelector(".unread-badge"))
  }

  // Derived from the selected feed, never stored: a morph refresh re-renders the
  // pane and would leave a stored index pointing at whatever moved into its slot.
  get activeIndex() {
    return this.activeId ? this.items.findIndex(item => item.dataset.feedId === this.activeId) : -1
  }

  // Private

  #activate(index) {
    const item = this.items[index]
    if (!item) return

    this.activeId = item.dataset.feedId
    this.#markActive()

    const link = item.matches("a") ? item : item.querySelector("a")
    if (link) link.click()

    scrollIntoViewIfNeeded(item, this.listTarget)
  }

  #markActive() {
    this.items.forEach(item => {
      if (item.dataset.feedId === this.activeId) {
        item.dataset.active = "true"
        item.setAttribute("aria-current", "true")
      } else {
        delete item.dataset.active
        item.removeAttribute("aria-current")
      }
    })
  }
}
