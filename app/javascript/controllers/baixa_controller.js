import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A production stage's baixa (Etapa 2.2, 2/3; decided 07/10/2026): "Baixa"
// opens the measure field next to the download; saving checks it against
// what the files expect. Outside the dono's band the server answers with a
// warning — correct the value, or "Confirmar assim mesmo" saves it marked.
// Once saved the page reloads (the line shows ✓ and who did it).
export default class extends Controller {
  static targets = ["abrir", "editor", "medida", "mensagem", "confirmar"]
  static values = { url: String, etapa: String, nivel: String, alvo: String }

  abrir() {
    this.abrirTarget.hidden = true
    this.editorTarget.hidden = false
    this.medidaTarget.focus()
  }

  cancelar() {
    this.editorTarget.hidden = true
    this.abrirTarget.hidden = false
    this.limpar()
  }

  // A new value asks again: the warning was about the previous one.
  editou() {
    this.limpar()
  }

  salvar(event) {
    event?.preventDefault()
    this.enviar(false)
  }

  confirmarAssim() {
    this.enviar(true)
  }

  enviar(confirmar) {
    const body = new FormData()
    Object.entries({ etapa: this.etapaValue, nivel: this.nivelValue, alvo: this.alvoValue, medida: this.medidaTarget.value, confirmar: confirmar ? "1" : "0" })
      .forEach(([campo, valor]) => body.append(campo, valor))
    const csrf = document.querySelector("meta[name='csrf-token']")?.content || ""
    fetch(this.urlValue, { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": csrf }, body })
      .then(r => r.json().catch(() => ({ ok: false, error: `HTTP ${r.status}` })))
      .then(data => this.responder(data))
      .catch(erro => this.mostrar(erro.message, false))
  }

  responder(data) {
    if (data.ok) return Turbo.visit(window.location.href, { action: "replace" })
    if (data.aviso) return this.mostrar(data.aviso, true)
    this.mostrar(data.error || "Não foi possível registrar a baixa", false)
  }

  mostrar(texto, podeConfirmar) {
    this.mensagemTarget.textContent = texto
    this.mensagemTarget.hidden = false
    this.mensagemTarget.classList.toggle("baixa-aviso", podeConfirmar)
    this.confirmarTarget.hidden = !podeConfirmar
  }

  limpar() {
    this.mensagemTarget.hidden = true
    this.confirmarTarget.hidden = true
  }
}
