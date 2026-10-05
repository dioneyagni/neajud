import { Controller } from "@hotwired/stimulus"

// Etapa 1.2 (2/3): bringing other artes into this one — a filter over the
// cards and a button that says how many are marked.
export default class extends Controller {
  static targets = ["busca", "card", "botao"]

  filtrar() {
    const termo = this.buscaTarget.value.trim().toLowerCase()
    this.cardTargets.forEach(card => {
      card.hidden = termo !== "" && !card.dataset.texto.includes(termo)
    })
  }

  contar() {
    const marcadas = this.element.querySelectorAll('input[name="origem_uuids[]"]:checked').length
    this.botaoTarget.disabled = marcadas === 0
    const textos = { 0: "Bring the marked artes", 1: "Bring the marked arte" }
    this.botaoTarget.textContent = textos[marcadas] || `Bring the ${marcadas} marked artes`
  }
}
