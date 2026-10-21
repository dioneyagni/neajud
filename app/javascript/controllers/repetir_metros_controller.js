import { Controller } from "@hotwired/stimulus"

// "Repetir pedido" (decided 20/10/2026): each item's "metros desta vez" from
// the meters of last time — Igual, Metade or Dobro, for one item or for all —
// rounded to one decimal (an item's meters take one), typed with a comma.
export default class extends Controller {
  static targets = ["campo"]

  item(event) {
    const campo = event.currentTarget.closest(".tecido-repetir-item").querySelector("[data-repetir-metros-target='campo']")
    this.aplicar(campo, event.params.fator)
  }

  todos(event) {
    this.campoTargets.forEach(campo => this.aplicar(campo, event.params.fator))
  }

  // Typed by hand: no shortcut is pressed any more.
  digitou(event) {
    this.marcar(event.currentTarget, null)
  }

  aplicar(campo, fator) {
    const metros = Math.round(parseFloat(campo.dataset.anterior) * fator * 10) / 10
    campo.value = String(metros).replace(".", ",")
    this.marcar(campo, fator)
  }

  marcar(campo, fator) {
    campo.closest(".tecido-repetir-item").querySelectorAll("[data-repetir-metros-fator-param]").forEach(botao => {
      botao.setAttribute("aria-pressed", String(fator !== null && parseFloat(botao.dataset.repetirMetrosFatorParam) === fator))
    })
  }
}
