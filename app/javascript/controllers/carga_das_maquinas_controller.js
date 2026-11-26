import { Controller } from "@hotwired/stimulus"

const CHAVE = "painel:carga-das-maquinas"

// Máquinas 5/5 (Q1a): ▸ opens a sector's machine rows in the Linha do
// tempo's load, closed at first; which ones are open is kept in the tab's
// sessionStorage and comes back after the Painel's refresh (a morph puts
// the server's hidden rows back) and a new window (‹ ›).
export default class extends Controller {
  connect() {
    this.reaplicar = () => this.mostrar()
    document.addEventListener("turbo:morph", this.reaplicar)
    this.mostrar()
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.reaplicar)
  }

  alternar(event) {
    const setor = event.currentTarget.dataset.setor
    const abertos = this.abertos()
    if (abertos.has(setor)) abertos.delete(setor)
    else abertos.add(setor)
    this.guardar(abertos)
    this.mostrar()
  }

  mostrar() {
    const abertos = this.abertos()
    this.element.querySelectorAll("[data-carga-maquinas-de]").forEach((linha) => { linha.hidden = !abertos.has(linha.dataset.cargaMaquinasDe) })
    this.element.querySelectorAll("[data-carga-abrir]").forEach((botao) => {
      const aberto = abertos.has(botao.dataset.setor)
      botao.setAttribute("aria-expanded", String(aberto))
      botao.textContent = aberto ? "▾" : "▸"
    })
  }

  abertos() {
    try { return new Set(JSON.parse(sessionStorage.getItem(CHAVE) || "[]")) } catch { return new Set() }
  }

  guardar(abertos) {
    try { sessionStorage.setItem(CHAVE, JSON.stringify([ ...abertos ])) } catch { /* private window: it just isn't kept */ }
  }
}
