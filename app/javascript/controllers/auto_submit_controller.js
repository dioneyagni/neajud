import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a file is picked, so a single "Enviar arquivo"
// click uploads (used on a pedido's pendência: the file goes into the arte),
// or as soon as a <select> changes (a file's side on the arte page, Etapa
// 1.2, 3/3 parte 3c).
// Usage: <form data-controller="auto-submit"><input type="file" data-action="change->auto-submit#submit"></form>
export default class extends Controller {
  submit(event) {
    const campo = event.currentTarget
    if (campo.type === "file" && !campo.files?.length) return
    this.element.querySelector(".pedido-peca-enviar-label")?.classList.add("pedido-peca-enviar-label--enviando")
    this.element.requestSubmit()
  }
}
