import { Controller } from "@hotwired/stimulus"

// Checks/unchecks a piece of a pedido item and saves it right away
// (PATCH alternar_peca). Unchecked = dimmed; the pedido goes to production
// without that piece. If the server refuses, the change is undone and the
// reason shown.
export default class extends Controller {
  static targets = ["error"]
  static values = { url: String }

  toggle(event) {
    const input = event.currentTarget
    const card = input.closest(".pedido-peca")
    this._paint(card, input.checked)
    this._hideError()
    input.disabled = true
    this._save(card.dataset.pecaId, input.checked)
      .catch(err => {
        input.checked = !input.checked
        this._paint(card, input.checked)
        this._showError(err.message)
      })
      .finally(() => { input.disabled = false })
  }

  _save(pecaId, incluida) {
    const body = new FormData()
    body.append("peca_id", pecaId)
    body.append("incluida", String(incluida))
    return fetch(this.urlValue, { method: "PATCH", headers: this._headers(), body })
      .then(r => r.json().catch(() => ({ ok: false, error: `HTTP ${r.status}` })))
      .then(data => { if (!data.ok) throw new Error(data.error || "Não foi possível salvar a peça") })
  }

  _headers() {
    const csrf = document.querySelector("[name='csrf-token']")
    return csrf ? { "Accept": "application/json", "X-CSRF-Token": csrf.content } : { "Accept": "application/json" }
  }

  _paint(card, incluida) {
    card.classList.toggle("pedido-peca--excluida", !incluida)
    card.classList.toggle("pedido-peca--incluida", incluida)
  }

  _showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  _hideError() {
    this.errorTarget.hidden = true
  }
}
