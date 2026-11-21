import { Controller } from "@hotwired/stimulus"

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
