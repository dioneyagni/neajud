import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a file is picked, so a single "Enviar arquivo"
// click uploads (used on a pedido's pendência: the file goes into the arte).
// Usage: <form data-controller="auto-submit"><input type="file" data-action="change->auto-submit#submit"></form>
export default class extends Controller {
  submit(event) {
    if (!event.currentTarget.files?.length) return
    this.element.querySelector(".pedido-peca-enviar-label")?.classList.add("pedido-peca-enviar-label--enviando")
    this.element.requestSubmit()
  }
}
