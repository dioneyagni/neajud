import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "moldeDialog", "pecaDialog", "dialogTitle", "submitBtn"]

  connect() {
    this.boundClose = this.backdropClose.bind(this)
    this.boundCloseMolde = this.backdropCloseMolde.bind(this)
    this.boundClosePeca = this.backdropClosePeca.bind(this)
  }

  open() {
    this._resetToCreate()
    this.dialogTarget.showModal()
    this.dialogTarget.addEventListener("click", this.boundClose)
  }

  openByName(e) {
    const name = e.params.name
    if (name === "molde") {
      this._resetDialogCreate(this.moldeDialogTarget)
      this.moldeDialogTarget.showModal()
      this.moldeDialogTarget.addEventListener("click", this.boundCloseMolde)
    } else if (name === "peca") {
      this._resetDialogCreate(this.pecaDialogTarget)
      this.pecaDialogTarget.showModal()
      this.pecaDialogTarget.addEventListener("click", this.boundClosePeca)
    }
  }

  closeMolde() {
    this.moldeDialogTarget.close()
    this.moldeDialogTarget.removeEventListener("click", this.boundCloseMolde)
  }

  closePeca() {
    this.pecaDialogTarget.close()
    this.pecaDialogTarget.removeEventListener("click", this.boundClosePeca)
  }

  backdropCloseMolde(e) {
    if (e.target !== this.moldeDialogTarget) return
    this.closeMolde()
  }

  backdropClosePeca(e) {
    if (e.target !== this.pecaDialogTarget) return
    this.closePeca()
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
    this._resetDialogCreate(this.dialogTarget)
  }

  _resetDialogCreate(dialog) {
    const form = dialog.querySelector("form")
    if (form) {
      form.reset()
      form.querySelector('input[name="_method"]')?.remove()
      const fields = form.querySelectorAll("[data-dialog-field]")
      fields.forEach(field => { field.value = "" })
    }
  }
}