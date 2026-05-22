import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form"]

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
    const firstInput = this.formTargets.find(el => el.style.display !== "none")?.querySelector("input:not([type=hidden])")
    if (firstInput) firstInput.focus()
  }

  resetFormValues() {
    this.element.querySelectorAll("input[data-original-value]").forEach(input => {
      input.value = input.dataset.originalValue
    })
  }

  onSuccess() {
    this.showDisplay()
  }
}