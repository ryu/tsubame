import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  entryRead({ detail: { feedItem } }) {
    const badge = feedItem?.querySelector(".unread-badge")
    if (!badge) return

    const count = parseInt(badge.textContent, 10)
    count > 1 ? (badge.textContent = count - 1) : badge.remove()
    this._refreshFolderBadge(feedItem)
  }

  feedLoaded({ detail: { feedId, isEmpty } }) {
    if (!isEmpty) return

    const feedItem = this.element.querySelector(`.feed-item[data-feed-id="${feedId}"]`)
    if (!feedItem) return

    const badge = feedItem.querySelector(".unread-badge")
    if (!badge) return

    badge.remove()
    this._refreshFolderBadge(feedItem)
  }

  _refreshFolderBadge(feedItem) {
    const header = this._findFolderHeader(feedItem)
    if (!header) return

    let total = 0
    let sibling = header.nextElementSibling
    while (sibling && !sibling.classList.contains("feed-folder-header")) {
      const b = sibling.querySelector(".unread-badge")
      if (b) total += parseInt(b.textContent, 10) || 0
      sibling = sibling.nextElementSibling
    }

    const folderBadge = header.querySelector(".unread-badge")
    if (folderBadge) {
      total > 0 ? (folderBadge.textContent = total) : folderBadge.remove()
    }
  }

  _findFolderHeader(feedItem) {
    let sibling = feedItem.previousElementSibling
    while (sibling) {
      if (sibling.classList.contains("feed-folder-header")) return sibling
      sibling = sibling.previousElementSibling
    }
    return null
  }
}
