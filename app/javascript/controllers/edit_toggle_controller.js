import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form"]

  connect() {
    this.showDisplay()
  }

  edit() {
    this.showForm()
  }

  cancel() {
    this.resetFormValues()
    this.showDisplay()
  }

  showDisplay() {
    this.displayTargets.forEach(el => el.style.display = "")
    this.formTargets.forEach(el => el.style.display = "none")
  }

  showForm() {
    this.displayTargets.forEach(el => el.style.display = "none")
    this.formTargets.forEach(el => el.style.display = "")
    const firstInput = this.formTarget.querySelector("input:not([type=hidden])")
    if (firstInput) firstInput.focus()
  }

  resetFormValues() {
    this.formTarget.querySelectorAll("input").forEach(input => {
      if (input.dataset.originalValue !== undefined) {
        input.value = input.dataset.originalValue
      }
    })
  }

  onSuccess() {
    this.showDisplay()
  }
}