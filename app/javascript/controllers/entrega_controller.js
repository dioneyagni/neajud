import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import DialogoDaFalta from "controllers/dialogo_da_falta"

// "Marcar como entregue" (Etapa 2.2, 3/3; decided 07/10/2026): never locked —
// when stages still have open lines the server names them and "Entregar
// assim mesmo" delivers anyway (a client may take what is ready).
// Material it still waits for (decided 05/11/2026): the dialog
// (DialogoDaFalta) launches the entry with the delivery.
export default class extends Controller {
  static targets = ["mensagem", "confirmar", "falta"]
  static values = { url: String }

  connect() {
    this.dialogoDaFalta = new DialogoDaFalta(this.faltaTarget)
  }

  entregar() {
    this.enviar(false)
  }

  confirmar() {
    this.enviar(true)
  }

  lancarFalta() {
    this.enviar(this.confirmou, this.dialogoDaFalta.campos())
  }

  fecharFalta() {
    this.dialogoDaFalta.fechar()
  }

  enviar(confirmar, extras = []) {
    this.confirmou = confirmar
    const body = new FormData()
    body.append("confirmar", confirmar ? "1" : "0")
    extras.forEach(([campo, valor]) => body.append(campo, valor))
    const csrf = document.querySelector("meta[name='csrf-token']")?.content || ""
    fetch(this.urlValue, { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": csrf }, body })
      .then(r => r.json().catch(() => ({ ok: false, error: `HTTP ${r.status}` })))
      .then(data => this.responder(data))
  }

  responder(data) {
    if (data.ok) return Turbo.visit(window.location.href, { action: "replace" })
    if (data.falta_material) return this.dialogoDaFalta.abrir(data.faltas, data.pode_lancar)
    if (this.dialogoDaFalta.aberto) return this.dialogoDaFalta.mostrarErro(data.error || "Não foi possível entregar")
    this.mensagemTarget.textContent = data.aviso || data.error
    this.mensagemTarget.classList.toggle("baixa-aviso", Boolean(data.aviso))
    this.mensagemTarget.hidden = false
    this.confirmarTarget.hidden = !data.aviso
  }
}
