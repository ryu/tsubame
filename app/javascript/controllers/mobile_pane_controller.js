import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!this._isMobile()) return

    this.element.setAttribute("data-mobile-pane", "feeds")

    this.boundHandleFrameLoad = this._handleFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)
  }

  disconnect() {
    if (this.boundHandleFrameLoad) {
      document.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
    }
  }

  showFeeds() {
    this.element.setAttribute("data-mobile-pane", "feeds")
  }

  showEntries() {
    this.element.setAttribute("data-mobile-pane", "entries")
  }

  showDetail() {
    this.element.setAttribute("data-mobile-pane", "detail")
  }

  // Private

  _handleFrameLoad(event) {
    if (!this._isMobile()) return

    if (event.target.id === "entry_list") {
      this.showEntries()
    } else if (event.target.id === "entry_detail") {
      this.showDetail()
    }
  }

  _isMobile() {
    return window.matchMedia("(max-width: 767px)").matches
  }
}
