import { Controller } from "@hotwired/stimulus"

// Máquinas 2/5a (the 4B mockup, 21/11/2026): a sector's queue filtered by
// machine — what that machine's operator sees. The choice is kept per
// sector in the tab's sessionStorage, and comes back after the Painel
// refreshes itself (a morph puts the server's classes back).
export default class extends Controller {
  static targets = ["chip"]
  static values = { setor: String }

  connect() {
    this.reaplicar = () => this.aplicar(this.guardada())
    document.addEventListener("turbo:morph", this.reaplicar)
    this.aplicar(this.guardada())
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.reaplicar)
  }

  filtrar(event) {
    const maquina = event.currentTarget.dataset.maquina
    this.guardar(maquina)
    this.aplicar(maquina)
  }

  aplicar(maquina) {
    const existe = this.chipTargets.some((chip) => chip.dataset.maquina === maquina)
    const escolhida = existe ? maquina : ""
    this.chipTargets.forEach((chip) => {
      const ativo = chip.dataset.maquina === escolhida
      chip.classList.toggle("painel-fila-filtro-chip--ativo", ativo)
      chip.setAttribute("aria-pressed", String(ativo))
    })
    this.element.querySelectorAll("[data-fila-pedido]").forEach((linha) => {
      linha.classList.toggle("painel-fila-l--outra-maquina", escolhida !== "" && linha.dataset.filaMaquina !== escolhida)
    })
  }

  chave() {
    return `painel:maquina:${this.setorValue}`
  }

  guardada() {
    try { return sessionStorage.getItem(this.chave()) || "" } catch { return "" }
  }

  guardar(maquina) {
    try { sessionStorage.setItem(this.chave(), maquina) } catch { /* private window: the filter just isn't kept */ }
  }
}
