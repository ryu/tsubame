import { Controller } from "@hotwired/stimulus"

// Reloads the current page without pushing a history entry.
export default class extends Controller {
  page() {
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
