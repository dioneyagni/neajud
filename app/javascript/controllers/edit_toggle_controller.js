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
    this.element.querySelectorAll("input[data-original-value], select[data-original-value]").forEach(field => {
      field.value = field.dataset.originalValue
      // A select's dependents (the grade type's label column) follow its change event.
      if (field.tagName === "SELECT") field.dispatchEvent(new Event("change"))
    })
  }

  onSuccess() {
    this.showDisplay()
  }
}