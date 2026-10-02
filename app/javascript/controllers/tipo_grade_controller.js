import { Controller } from "@hotwired/stimulus"

// Etapa 1.2 (1/3): P/M/G and Furada sizes carry a label (P, M, "22 ao 24")
// before the sizes they serve; Par and Ímpar build it from the pair.
export default class extends Controller {
  static targets = ["select"]
  static TIPOS_COM_ROTULO = ["pmg", "furada"]

  connect() {
    this.mostrarRotulos()
  }

  mostrarRotulos() {
    const comRotulo = this.constructor.TIPOS_COM_ROTULO.includes(this.selectTarget.value)
    this.element.closest("form").querySelectorAll(".tamanho-rotulo").forEach(input => {
      input.hidden = !comRotulo
    })
  }
}
