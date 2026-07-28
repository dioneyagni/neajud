import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["moldeSelect", "pecaSelect"]

  connect() {
    const moldeId = this.moldeSelectTarget.value
    if (moldeId) {
      this.fetchPecas(moldeId)
    }
  }

  onMoldeChange() {
    const moldeId = this.moldeSelectTarget.value

    if (!moldeId) {
      this.fetchAllPecas()
      return
    }

    this.fetchPecas(moldeId)
  }

  fetchPecas(moldeId) {
    fetch(`/moldes/${moldeId}/pecas`)
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
