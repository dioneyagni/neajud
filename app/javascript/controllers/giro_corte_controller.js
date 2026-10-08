import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Saves a corte's "Giro no encaixe" (Etapa 2.2, 1/3) as soon as a radio is
// picked. Not a <form>: it sits inside the organize form, and a nested form
// breaks the outer one (AGENTS.md "Nested forms gotcha"). Reloads the page
// once saved (the sizes' consumption is being recomputed).
export default class extends Controller {
  static targets = ["erro"]
  static values = { url: String }

  salvar(event) {
    const body = new FormData()
    body.append("giro", event.currentTarget.value)
    const csrf = document.querySelector("meta[name='csrf-token']")?.content || ""
    fetch(this.urlValue, { method: "PATCH", headers: { "Accept": "application/json", "X-CSRF-Token": csrf }, body })
      .then(r => r.json().catch(() => ({ ok: false, error: `HTTP ${r.status}` })))
      .then(data => {
        if (!data.ok) throw new Error(data.error || "Não foi possível salvar o giro")
        Turbo.visit(window.location.href, { action: "replace" })
      })
      .catch(erro => {
        this.erroTarget.textContent = erro.message
        this.erroTarget.hidden = false
      })
  }
}
