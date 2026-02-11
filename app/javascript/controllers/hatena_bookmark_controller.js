import { Controller } from "@hotwired/stimulus"
import { openHatenaBookmarkPage } from "lib/hatena_bookmark"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    this.isLoading = false

    this.boundHandleFrameLoad = this._handleFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)

    this._fetchBookmarkCounts()
  }

  disconnect() {
    this.abortController.abort()
    document.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
  }

  // Stimulus action: called via data-action on count spans
  openBookmarkPage(event) {
    event.preventDefault()
    event.stopPropagation()
    openHatenaBookmarkPage(event.currentTarget.dataset.url)
  }

  // Private methods

  _handleFrameLoad(event) {
    if (event.target.id === "entry_list") {
      this._fetchBookmarkCounts()
    }
  }

  _fetchBookmarkCounts() {
    if (this.isLoading) return
    this.isLoading = true

    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) {
      this.isLoading = false
      return
    }

    const urls = []
    const urlToEntries = new Map()

    entryItems.forEach(item => {
      const url = item.dataset.entryUrl
      if (!url) return

      if (!urlToEntries.has(url)) {
        urls.push(url)
        urlToEntries.set(url, [])
      }
      urlToEntries.get(url).push(item)
    })

    if (urls.length === 0) {
      this.isLoading = false
      return
    }

    const batches = this._createBatches(urls, 20)
    const fetchPromises = batches.map(batch =>
      this._fetchBatchCounts(batch, urlToEntries)
    )

    Promise.allSettled(fetchPromises).finally(() => {
      this.isLoading = false
    })
  }

  _createBatches(array, size) {
    const batches = []
    for (let i = 0; i < array.length; i += size) {
      batches.push(array.slice(i, i + size))
    }
    return batches
  }

  _fetchBatchCounts(urls, urlToEntries) {
    const params = urls.map(url => `url=${encodeURIComponent(url)}`).join("&")
    const apiUrl = `https://bookmark.hatenaapis.com/count/entries?${params}`

    return fetch(apiUrl, {
      method: "GET",
      signal: this.abortController.signal
    })
      .then(response => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.json()
      })
      .then(data => {
        this._updateCounts(data, urlToEntries)
      })
      .catch(error => {
        if (error.name !== "AbortError") {
          console.warn("Failed to fetch Hatena Bookmark counts:", error)
        }
      })
  }

  _updateCounts(data, urlToEntries) {
    Object.entries(data).forEach(([url, count]) => {
      const entryItems = urlToEntries.get(url)
      if (!entryItems) return

      entryItems.forEach(item => {
        const countSpan = item.querySelector(".hatena-count")
        if (!countSpan) return

        if (count > 0) {
          countSpan.textContent = `B!${count}`
          countSpan.classList.add("hatena-count-clickable")
          countSpan.dataset.url = url
          countSpan.dataset.action = "click->hatena-bookmark#openBookmarkPage"
        } else {
          countSpan.textContent = ""
          countSpan.classList.remove("hatena-count-clickable")
          delete countSpan.dataset.action
        }
      })
    })
  }

  _getEntryItems() {
    return Array.from(this.element.querySelectorAll(".entry-item"))
  }
}
