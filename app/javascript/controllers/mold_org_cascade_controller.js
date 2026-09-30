import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Option values are uuids (Etapa 1.1): /modelos/<uuid>/pecas answers
  // { id: <peca uuid>, nome }.
  static targets = ["modeloSelect", "pecaSelect"]

  connect() {
    const modeloUuid = this.modeloSelectTarget.value
    if (modeloUuid) {
      this.fetchPecas(modeloUuid)
    }
  }

  onModeloChange() {
    const modeloUuid = this.modeloSelectTarget.value

    if (!modeloUuid) {
      this.fetchAllPecas()
      return
    }

    this.fetchPecas(modeloUuid)
  }

  fetchPecas(modeloUuid) {
    fetch(`/modelos/${modeloUuid}/pecas`)
      .then(r => r.json())
      .then(pecas => {
        const current = this.pecaSelectTarget.dataset.originalValue || ""
        this.pecaSelectTarget.innerHTML = '<option value="">Select a piece...</option>' +
          pecas.map(p => {
            const selected = String(p.id) === String(current) ? "selected" : ""
            return `<option value="${p.id}" ${selected}>${p.nome}</option>`
          }).join("")
      })
  }

  fetchAllPecas() {
    fetch("/pecas/search?q=")
      .then(r => r.json())
      .then(pecas => {
        this.pecaSelectTarget.innerHTML = '<option value="">Select a piece...</option>' +
          pecas.map(p => `<option value="${p.id}">${p.nome}</option>`).join("")
      })
  }
}
