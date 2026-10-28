import { Controller } from "@hotwired/stimulus"

// Dublagem 1/5 (decided 27/10/2026): the stock entry asks what the chosen
// group asks for (GrupoMaterial#atributos, { name: required? }); a field it
// doesn't ask is hidden and disabled, so it isn't sent. With no group yet,
// the gramatura alone, as before 1/5.
// Usage: <div data-controller="atributos-do-grupo"
//          data-action="group-select:escolhido->atributos-do-grupo#mostrar">
// with the group's hidden input as target "grupo" (data-atributos) and each
// field as target "campo" (data-atributo="densidade").
export default class extends Controller {
  static targets = ["grupo", "campo"]

  connect() {
    this.mostrar()
  }

  mostrar() {
    const atributos = JSON.parse(this.grupoTarget.dataset.atributos || '{"gramatura":true}')
    this.campoTargets.forEach(campo => {
      const nome = campo.dataset.atributo
      const pede = nome in atributos
      campo.hidden = !pede
      campo.querySelectorAll("input").forEach(input => { input.disabled = !pede })
      campo.querySelector(".atributo-obrigatorio")?.toggleAttribute("hidden", !atributos[nome])
    })
  }
}
