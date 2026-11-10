import { Controller } from "@hotwired/stimulus"

// One row of the rede's Situações card (rede editável 2/2b): "Renomear"
// swaps the name for its form in the same row; "Cancelar" puts the name
// back and forgets what was typed.
export default class extends Controller {
  static targets = ["vista", "formulario", "campo"]

  renomear() {
    this.vistaTarget.hidden = true
    this.formularioTarget.hidden = false
    this.campoTarget.focus()
    this.campoTarget.select()
  }

  cancelar() {
    this.formularioTarget.reset()
    this.formularioTarget.hidden = true
    this.vistaTarget.hidden = false
  }
}
