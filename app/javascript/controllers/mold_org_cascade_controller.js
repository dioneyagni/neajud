import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Option values are uuids (Etapa 1.1): /moldes/<uuid>/pecas answers
  // { id: <peca uuid>, nome }.
  static targets = ["moldeSelect", "pecaSelect"]

  connect() {
    const moldeUuid = this.moldeSelectTarget.value
    if (moldeUuid) {
      this.fetchPecas(moldeUuid)
    }
  }

  onMoldeChange() {
    const moldeUuid = this.moldeSelectTarget.value

    if (!moldeUuid) {
      this.fetchAllPecas()
      return
    }

    this.fetchPecas(moldeUuid)
  }

  fetchPecas(moldeUuid) {
    fetch(`/moldes/${moldeUuid}/pecas`)
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
