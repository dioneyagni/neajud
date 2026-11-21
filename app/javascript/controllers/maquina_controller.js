import { Controller } from "@hotwired/stimulus"

// A machine's page (Máquinas 1/5): a trabalho's speed — the Corte do
// calçado's parameters — is typed only while it is checked; unchecked, the
// field is disabled (and so not sent: the machine no longer does it).
export default class extends Controller {
  marcar(event) {
    const chave = event.params.trabalho
    this.element.querySelectorAll(`[data-velocidade-de="${chave}"]`).forEach((campo) => {
      campo.disabled = !event.target.checked
      if (event.target.checked && campo.name.endsWith("[por_hora]")) campo.focus()
    })
  }
}
