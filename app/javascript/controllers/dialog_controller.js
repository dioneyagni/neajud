import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "modeloDialog", "pecaDialog", "dialogTitle", "submitBtn"]

  connect() {
    this.boundClose = this.backdropClose.bind(this)
    this.boundCloseModelo = this.backdropCloseModelo.bind(this)
    this.boundClosePeca = this.backdropClosePeca.bind(this)
  }

  open() {
    this._resetToCreate()
    this.dialogTarget.showModal()
    this.dialogTarget.addEventListener("click", this.boundClose)
  }

  openByName(e) {
    const name = e.params.name
    if (name === "modelo") {
      this._resetDialogCreate(this.modeloDialogTarget)
      this.modeloDialogTarget.showModal()
      this.modeloDialogTarget.addEventListener("click", this.boundCloseModelo)
    } else if (name === "peca") {
      this._resetDialogCreate(this.pecaDialogTarget)
      this.pecaDialogTarget.showModal()
      this.pecaDialogTarget.addEventListener("click", this.boundClosePeca)
    }
  }

  closeModelo() {
    this.modeloDialogTarget.close()
    this.modeloDialogTarget.removeEventListener("click", this.boundCloseModelo)
  }

  closePeca() {
    this.pecaDialogTarget.close()
    this.pecaDialogTarget.removeEventListener("click", this.boundClosePeca)
  }

  backdropCloseModelo(e) {
    if (e.target !== this.modeloDialogTarget) return
    this.closeModelo()
  }

  backdropClosePeca(e) {
    if (e.target !== this.pecaDialogTarget) return
    this.closePeca()
  }

  edit(e) {
    const btn = e.currentTarget
    const form = this.dialogTarget.querySelector("form")
    this._somenteEdicao(true)
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
    this._resetDialogCreate(this.dialogTarget)
    this._somenteEdicao(false)
  }

  // Options marked data-somente-edicao (e.g. the molde's trashed client)
  // only make sense when editing a record that already points at them.
  _somenteEdicao(mostrar) {
    this.dialogTarget.querySelectorAll("[data-somente-edicao]").forEach((el) => {
      el.hidden = !mostrar
      el.disabled = !mostrar
    })
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