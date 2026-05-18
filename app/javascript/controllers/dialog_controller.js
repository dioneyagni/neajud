import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.boundClose = this.backdropClose.bind(this)
  }

  open() {
    this.dialogTarget.showModal()
    this.dialogTarget.addEventListener("click", this.boundClose)
  }

  backdropClose(e) {
    if (e.target !== this.dialogTarget) return
    this.close()
  }

  close() {
    this.dialogTarget.close()
    this.dialogTarget.removeEventListener("click", this.boundClose)
  }
}
