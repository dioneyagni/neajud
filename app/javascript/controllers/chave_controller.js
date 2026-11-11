import { Controller } from "@hotwired/stimulus"

// The construção's chave (Dublagem 5b1a): draws the line from each card (or
// "segue" card) to the one it goes into — data-no names a card, data-saida
// the card it feeds — as elbows in an SVG behind the columns. Redrawn when
// the columns change size; montar replaces the whole chave, reconnecting it.
// Usage: <div data-controller="chave"><div data-chave-target="colunas"><svg data-chave-target="fios"></svg>…</div></div>
export default class extends Controller {
  static targets = ["colunas", "fios"]

  connect() {
    this.observador = new ResizeObserver(() => this.desenhar())
    this.observador.observe(this.colunasTarget)
    this.desenhar()
  }

  disconnect() {
    this.observador?.disconnect()
  }

  desenhar() {
    const base = this.colunasTarget.getBoundingClientRect()
    this.fiosTarget.setAttribute("width", this.colunasTarget.scrollWidth)
    this.fiosTarget.setAttribute("height", this.colunasTarget.scrollHeight)
    const caminhos = [...this.colunasTarget.querySelectorAll("[data-saida]")].flatMap((origem) => {
      const destino = this.colunasTarget.querySelector(`[data-no="${origem.dataset.saida}"]`)
      return destino ? [this.caminho(origem.getBoundingClientRect(), destino.getBoundingClientRect(), base)] : []
    })
    this.fiosTarget.innerHTML = caminhos.map((d) => `<path d="${d}"></path>`).join("")
  }

  // From the right middle of one card to the left middle of the other,
  // turning halfway between the columns.
  caminho(origem, destino, base) {
    const x1 = origem.right - base.left
    const y1 = origem.top + origem.height / 2 - base.top
    const x2 = destino.left - base.left
    const y2 = destino.top + Math.min(destino.height / 2, 120) - base.top
    const meio = (x1 + x2) / 2
    return `M${x1} ${y1} H${meio} V${y2} H${x2}`
  }
}
