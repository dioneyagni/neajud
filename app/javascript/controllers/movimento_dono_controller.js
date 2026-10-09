import { Controller } from "@hotwired/stimulus"

// Etapa 2.3: a movement of the empresa's own stock has no client, so the
// Client field hides while "Empresa" is checked (the server drops a client
// sent with it anyway — MovimentoCreatable).
// Usage: <div data-controller="movimento-dono"> with the radio
// data-movimento-dono-target="empresa" and the field target "cliente".
export default class extends Controller {
  static targets = ["empresa", "cliente"]

  connect() {
    this.mostrar()
  }

  mostrar() {
    this.clienteTarget.hidden = this.empresaTarget.checked
  }
}
