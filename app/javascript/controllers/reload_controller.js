import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  page() {
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
