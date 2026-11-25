import { Controller } from "@hotwired/stimulus"

// A new stop's window (Máquinas 3/5a): the machines' box of the stage
// picked only — the others hidden and disabled, so not sent —; "até"
// follows "de" while it is blank or before it (one day by default).
export default class extends Controller {
  static targets = ["maquinas", "inicio", "fim"]

  escolherEtapa(event) {
    this.maquinasTargets.forEach((caixa) => {
      const dela = caixa.dataset.etapa === event.target.value
      caixa.hidden = !dela
      caixa.disabled = !dela
    })
  }

  copiarInicio() {
    if (!this.fimTarget.value || this.fimTarget.value < this.inicioTarget.value) this.fimTarget.value = this.inicioTarget.value
  }
}
