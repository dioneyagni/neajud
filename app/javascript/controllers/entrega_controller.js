import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// "Marcar como entregue" (Etapa 2.2, 3/3; decided 07/10/2026): never locked —
// when stages still have open lines the server names them and "Entregar
// assim mesmo" delivers anyway (a client may take what is ready).
export default class extends Controller {
  static targets = ["mensagem", "confirmar"]
  static values = { url: String }

  entregar() {
    this.enviar(false)
  }

  confirmar() {
    this.enviar(true)
  }

  enviar(confirmar) {
    const body = new FormData()
    body.append("confirmar", confirmar ? "1" : "0")
    const csrf = document.querySelector("meta[name='csrf-token']")?.content || ""
    fetch(this.urlValue, { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": csrf }, body })
      .then(r => r.json().catch(() => ({ ok: false, error: `HTTP ${r.status}` })))
      .then(data => {
        if (data.ok) return Turbo.visit(window.location.href, { action: "replace" })
        this.mensagemTarget.textContent = data.aviso || data.error
        this.mensagemTarget.classList.toggle("baixa-aviso", Boolean(data.aviso))
        this.mensagemTarget.hidden = false
        this.confirmarTarget.hidden = !data.aviso
      })
  }
}
