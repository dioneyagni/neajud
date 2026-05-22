import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "dialogTitle", "submitBtn"]

  connect() {
    this.boundClose = this.backdropClose.bind(this)
  }

  open() {
    this._resetToCreate()
    this.dialogTarget.showModal()
    this.dialogTarget.addEventListener("click", this.boundClose)
  }

  edit(e) {
    const btn = e.currentTarget
    const form = this.dialogTarget.querySelector("form")
    const fields = form.querySelectorAll("[data-dialog-field]")

    fields.forEach(field => {
      const key = field.dataset.dialogField
      field.value = btn.dataset[key] || ""
    })

    if (this.hasDialogTitleTarget) {
      this.dialogTitleTarget.textContent = btn.dataset.dialogTitle || "Edit"
    }
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.textContent = btn.dataset.submitLabel || "Update"
    }

    const existingMethod = form.querySelector('input[name="_method"]')
    const actionUrl = btn.dataset.actionUrl
    if (actionUrl) {
      form.action = actionUrl
    }
    if (btn.dataset.method === "patch") {
      if (existingMethod) {
        existingMethod.value = "patch"
      } else {
        const methodInput = document.createElement("input")
        methodInput.type = "hidden"
        methodInput.name = "_method"
        methodInput.value = "patch"
        form.prepend(methodInput)
      }
    } else if (existingMethod) {
      existingMethod.remove()
    }

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

  _resetToCreate() {
    const form = this.dialogTarget.querySelector("form")
    form.reset()
    form.querySelector('input[name="_method"]')?.remove()

    const fields = form.querySelectorAll("[data-dialog-field]")
    fields.forEach(field => { field.value = "" })

    if (this.hasDialogTitleTarget) {
      this.dialogTitleTarget.textContent = this.element.dataset.createTitle || "Register New"
    }
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.textContent = this.element.dataset.createLabel || "Register"
    }

    const createUrl = this.element.dataset.createUrl
    if (createUrl) {
      form.action = createUrl
    }
  }
}