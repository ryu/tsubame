import { Controller } from "@hotwired/stimulus"
import { openHatenaBookmarkPage } from "lib/hatena_bookmark"

const BATCH_SIZE = 20

export default class extends Controller {
  connect() {
    this.abortController = null
    this.pendingFetch = false

    this.boundHandleFrameLoad = this._handleFrameLoad.bind(this)
    this.element.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)

    this._fetchBookmarkCounts()
  }

  disconnect() {
    this.abortController?.abort()
    this.element.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
  }

  // Stimulus action: called via data-action on count spans
  openBookmarkPage(event) {
    event.preventDefault()
    event.stopPropagation()
    openHatenaBookmarkPage(event.currentTarget.dataset.url)
  }

  // Private methods

  _handleFrameLoad(event) {
    if (event.target !== this.element) return

    this._fetchBookmarkCounts()
  }

  // If a fetch is already in progress, queue one re-fetch after it completes.
  // Multiple queued requests collapse into a single re-fetch (1-stage queue).
  _fetchBookmarkCounts() {
    if (this.abortController) {
      this.pendingFetch = true
      return
    }

    this.abortController = new AbortController()

    const entryItems = this._getEntryItems()
    if (entryItems.length === 0) {
      this._finishFetch()
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
      this._finishFetch()
      return
    }

    const batches = this._createBatches(urls, BATCH_SIZE)
    const fetchPromises = batches.map(batch =>
      this._fetchBatchCounts(batch, urlToEntries)
    )

    Promise.allSettled(fetchPromises).finally(() => {
      this._finishFetch()
    })
  }

  _finishFetch() {
    this.abortController = null

    if (this.pendingFetch) {
      this.pendingFetch = false
      this._fetchBookmarkCounts()
    }
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
          delete countSpan.dataset.url
        }
      })
    })
  }

  _getEntryItems() {
    return Array.from(this.element.querySelectorAll(".entry-item"))
  }
}
