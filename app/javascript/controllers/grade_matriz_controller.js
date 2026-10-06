import { Controller } from "@hotwired/stimulus"

// The pedido page's matrix (Etapa 1.2, 3/3 parte 3a): the server renders a
// column per number of the product's grade, hiding those outside the molde's
// DXF numbers; "+ 28" / "+ 32" show the next hidden one before the first or
// after the last shown, like grade-por-numero does in the add-to-order modal.
export default class extends Controller {
  static targets = ["antes", "depois"]
  static values = { ordem: Array }

  connect() {
    this.rotular()
  }

  antes() {
    this.mostrar(this.vizinho(-1))
  }

  depois() {
    this.mostrar(this.vizinho(1))
  }

  mostrar(numero) {
    if (!numero) return
    this.element.querySelectorAll(`[data-numero="${CSS.escape(numero)}"]`).forEach(el => { el.hidden = false })
    this.rotular()
  }

  // The number just before the first (-1) or after the last (1) shown.
  vizinho(direcao) {
    const visiveis = this.ordemValue.filter(n => !this.element.querySelector(`.pedido-matriz-numero[data-numero="${CSS.escape(n)}"]`)?.hidden)
    const borda = direcao < 0 ? visiveis[0] : visiveis[visiveis.length - 1]
    return this.ordemValue[this.ordemValue.indexOf(borda) + direcao]
  }

  rotular() {
    [[this.antesTarget, this.vizinho(-1)], [this.depoisTarget, this.vizinho(1)]].forEach(([botao, numero]) => {
      botao.hidden = !numero
      botao.textContent = numero ? `+ ${numero}` : ""
    })
  }
}
