import { Controller } from "@hotwired/stimulus"

// Manages help dialog visibility
export default class extends Controller {
  static targets = ["dialog"]

  toggle() {
    if (!this.hasDialogTarget) return

    if (this.dialogTarget.open) {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.showModal()
    }
  }

  close() {
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }
}
