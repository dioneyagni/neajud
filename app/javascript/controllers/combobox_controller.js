import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { searchUrl: String }

  connect() {
    this.selected = false
  }

  search() {
    const q = this.input.value.trim()
    if (this.selected) { this.selected = false; return }

    fetch(`${this.searchUrlValue}?q=${encodeURIComponent(q)}`)
      .then(r => r.json())
      .then(clients => {
        this.results.innerHTML = clients.map(c => `
          <div class="combobox-option" data-id="${c.id}" data-name="${c.name.replace(/"/g, '&quot;')}" data-action="click->combobox#select">
            <strong>${this._highlight(c.name, q)}</strong>
            <span class="combobox-option-detail">${this._highlight(c.responsible, q)}</span>
          </div>
        `).join("") + `
          <div class="combobox-option combobox-option-new" data-action="click->combobox#openNew">
            + Register new client
          </div>
        `
        this.results.classList.add("combobox-results--open")
      })
  }

  select(e) {
    const opt = e.currentTarget
    this.input.value = opt.dataset.name
    this.hidden.value = opt.dataset.id
    this.selected = true
    this.results.classList.remove("combobox-results--open")
    this.save()
  }

  openNew() {
    this.results.classList.remove("combobox-results--open")
    const dialogEl = this.element.closest("[data-controller='dialog']")
    if (dialogEl) {
      const dialogController = this.application.getControllerForElementAndIdentifier(dialogEl, "dialog")
      dialogController.open()
    }
  }

  blur() {
    setTimeout(() => this.results.classList.remove("combobox-results--open"), 200)
  }

  save() {
    const form = this.element.closest("form")
    if (form) form.requestSubmit()
  }

  get input() {
    return this.element.querySelector(".combobox-input")
  }

  get hidden() {
    return document.getElementById("client_id")
  }

  get results() {
    return this.element.querySelector(".combobox-results")
  }

  _highlight(text, query) {
    if (!query) return text
    const idx = text.toLowerCase().indexOf(query.toLowerCase())
    if (idx === -1) return text
    return text.slice(0, idx) + "<mark>" + text.slice(idx, idx + query.length) + "</mark>" + text.slice(idx + query.length)
  }
}
