import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "clientForm", "dialogTitle", "submitBtn"]

  connect() {
    this.boundClose = this.backdropClose.bind(this)
  }

  open() {
    this._resetToCreate()
    this.dialogTarget.showModal()
    this.dialogTarget.addEventListener("click", this.boundClose)
  }

  editClient(e) {
    const btn = e.currentTarget
    this.dialogTarget.querySelector("#client_name_dialog").value = btn.dataset.clientName
    this.dialogTarget.querySelector("#client_responsible_dialog").value = btn.dataset.clientResponsible
    this.dialogTitleTarget.textContent = "Edit Client"
    this.submitBtnTarget.textContent = "Update"
    this.clientFormTarget.action = `/clients/${btn.dataset.clientId}`
    const existingMethod = this.clientFormTarget.querySelector('input[name="_method"]')
    if (existingMethod) {
      existingMethod.value = "patch"
    } else {
      const methodInput = document.createElement("input")
      methodInput.type = "hidden"
      methodInput.name = "_method"
      methodInput.value = "patch"
      this.clientFormTarget.prepend(methodInput)
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
    this.dialogTitleTarget.textContent = "Register New Client"
    this.submitBtnTarget.textContent = "Register"
    this.clientFormTarget.action = "/clients"
    this.clientFormTarget.querySelector('input[name="_method"]')?.remove()
    this.dialogTarget.querySelector("#client_name_dialog").value = ""
    this.dialogTarget.querySelector("#client_responsible_dialog").value = ""
  }
}
