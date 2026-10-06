import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Checks/unchecks a piece of a pedido item and saves it right away
// (PATCH alternar_peca). Unchecked = dimmed (its label and its row of the
// matrix); the pedido goes to production without that piece, and its
// pendências stop blocking — so the page morph-refreshes once saved (Etapa
// 1.2, 3/3 parte 3a). If the server refuses, the change is undone and the
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
    this._save(card.dataset.pecaUuid, input.checked)
      .then(() => Turbo.visit(window.location.href, { action: "replace" }))
      .catch(err => {
        input.checked = !input.checked
        this._paint(card, input.checked)
        this._showError(err.message)
      })
      .finally(() => { input.disabled = false })
  }

  _save(pecaUuid, incluida) {
    const body = new FormData()
    body.append("peca_uuid", pecaUuid)
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
    this.element.querySelectorAll(`.pedido-parte-numero[data-peca-uuid="${card.dataset.pecaUuid}"]`)
      .forEach(cell => cell.classList.toggle("pedido-parte-numero--excluida", !incluida))
  }

  _showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  _hideError() {
    this.errorTarget.hidden = true
  }
}
