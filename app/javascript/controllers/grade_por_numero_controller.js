import { Controller } from "@hotwired/stimulus"

// A pedido item's grade by individual size (Etapa 1.2, 3/3; decided
// 05/10/2026): the molde's stretch listed first (24 … 34), "+ 23" / "+ 35"
// to add the next number of the product's grade outside it, and a table that
// lays number over quantity on wide screens, side by side on narrow ones (CSS).
// Used by the add-to-order modal and the pedido page; the inputs carry the
// class those read (inputClass) and data-tamanho-nome.
export default class extends Controller {
  static values = { tamanhos: Array, completa: Array, quantidades: Object, inputClass: String }

  connect() {
    const ordem = this.completaValue.length ? this.completaValue : this.tamanhosValue
    const comQuantidade = Object.keys(this.quantidadesValue).filter(t => this.quantidadesValue[t] > 0)
    this.ordem = ordem
    this.visiveis = ordem.filter(t => this.tamanhosValue.includes(t) || comQuantidade.includes(t))
    this.quantidades = { ...this.quantidadesValue }
    this.render()
  }

  antes() {
    this.guardarDigitado()
    this.visiveis.unshift(this.vizinho(-1))
    this.render()
  }

  depois() {
    this.guardarDigitado()
    this.visiveis.push(this.vizinho(1))
    this.render()
  }

  // The number of the product's grade just before the first (-1) or after the last (1) listed.
  vizinho(direcao) {
    const borda = direcao < 0 ? this.visiveis[0] : this.visiveis[this.visiveis.length - 1]
    return this.ordem[this.ordem.indexOf(borda) + direcao]
  }

  guardarDigitado() {
    this.element.querySelectorAll("input[data-tamanho-nome]").forEach(input => {
      this.quantidades[input.dataset.tamanhoNome] = parseInt(input.value, 10) || 0
    })
  }

  render() {
    const antes = this.vizinho(-1)
    const depois = this.vizinho(1)
    this.element.innerHTML = `<div class="grade-numeros">
      ${antes ? `<button type="button" class="btn btn-sm btn-secondary grade-numeros-mais" data-action="grade-por-numero#antes">+ ${antes}</button>` : ""}
      <div class="grade-numeros-tabela">${this.visiveis.map(t => this.celula(t)).join("")}</div>
      ${depois ? `<button type="button" class="btn btn-sm btn-secondary grade-numeros-mais" data-action="grade-por-numero#depois">+ ${depois}</button>` : ""}
    </div>`
  }

  celula(tamanho) {
    return `<label class="grade-numero">
      <span class="grade-numero-rotulo">${tamanho}</span>
      <input type="number" class="${this.inputClassValue}" data-tamanho-nome="${tamanho}" value="${this.quantidades[tamanho] || 0}" min="0" step="1">
    </label>`
  }
}
