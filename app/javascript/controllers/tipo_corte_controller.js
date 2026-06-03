import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio", "form", "artesList"]
  static values = { linked: Boolean }

  change(e) {
    const value = e.target.value
    if (value === "apenas_corte" && this.linkedValue) {
      if (!confirm("Este corte possui artes vinculadas. Mudar para \"Apenas Corte\" ocultará a lista de artes, mas as relações serão mantidas para permitir reversão. Continuar?")) {
        this.resetToPrevious()
        return
      }
    }
    this.formTarget.requestSubmit()
  }

  resetToPrevious() {
    this.radioTargets.forEach(r => {
      r.checked = r.value === "corte_estampa"
    })
  }
}
