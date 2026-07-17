import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "lista", "model"]

  static values = {
    searchUrl: String,
    registerUrl: String
  }

  connect() {
    this.selected = false
    this.pecaIndex = this.listaTarget.children.length
  }

  search() {
    const q = this.inputTarget.value.trim()
    if (this.selected) { this.selected = false; return }

    fetch(`${this.searchUrlValue}?q=${encodeURIComponent(q)}`)
      .then(r => r.json())
      .then(items => {
        this.resultsTarget.innerHTML = items.map(item => `
          <div class="combobox-option" data-id="${item.id}" data-nome="${item.nome.replace(/"/g, '&quot;')}" data-action="click->componentes#select">
            <strong>${this._highlight(item.nome, q)}</strong>
          </div>
        `).join("") + `
          <div class="combobox-option combobox-option-new" data-action="click->componentes#openNew">
            + Register new
          </div>
        `
        this.resultsTarget.classList.add("combobox-results--open")
      })
  }

  select(e) {
    const opt = e.currentTarget
    const nome = opt.dataset.nome
    const id = opt.dataset.id

    this.resultsTarget.classList.remove("combobox-results--open")
    this.inputTarget.value = ""
    this.inputTarget.focus()

    const already = this.listaTarget.querySelector(`[data-peca-id="${id}"]`)
    if (already) return

    const row = this.modelTarget.content.cloneNode(true)
    const li = row.querySelector("li")
    li.dataset.pecaId = id
    li.querySelector(".componente-nome").textContent = nome
    li.querySelector("input").value = id
    this.listaTarget.appendChild(row)

    this.pecaIndex++
  }

  remove(e) {
    e.currentTarget.closest("li").remove()
  }

  openNew() {
    this.resultsTarget.classList.remove("combobox-results--open")
    if (this.registerUrlValue) {
      window.location.href = this.registerUrlValue
    }
  }

  blur() {
    setTimeout(() => this.resultsTarget.classList.remove("combobox-results--open"), 200)
  }

  _highlight(text, query) {
    if (!query) return text
    const idx = text.toLowerCase().indexOf(query.toLowerCase())
    if (idx === -1) return text
    return text.slice(0, idx) + "<mark>" + text.slice(idx, idx + query.length) + "</mark>" + text.slice(idx + query.length)
  }
}
