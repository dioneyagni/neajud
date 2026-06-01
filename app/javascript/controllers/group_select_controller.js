import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "hidden", "dialog"]

  connect() {
    this.abortController = null
    this._debounceTimer = null
  }

  search() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._doSearch(), 150)
  }

  _doSearch() {
    const q = this.inputTarget.value.trim()

    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    fetch(`/materiais/grupos?q=${encodeURIComponent(q)}`, { signal: this.abortController.signal })
      .then(r => r.json())
      .then(items => {
        this.resultsTarget.innerHTML = items.map(item =>
          `<div class="combobox-option" data-id="${item.id}" data-name="${item.nome}" data-action="click->group-select#select">
            <strong>${this._highlight(item.nome, q)}</strong>
          </div>`
        ).join("") + `
          <div class="combobox-option combobox-option-new" data-action="click->group-select#openNew">
            + Register new
          </div>`
        this.resultsTarget.classList.add("combobox-results--open")
      }).catch(() => {})
  }

  select(e) {
    const opt = e.currentTarget
    this.inputTarget.value = opt.dataset.name
    this.hiddenTarget.value = opt.dataset.id
    this.resultsTarget.classList.remove("combobox-results--open")
  }

  openNew() {
    this.resultsTarget.classList.remove("combobox-results--open")
    this.dialogTarget.showModal()
  }

  closeNew() {
    this.dialogTarget.close()
  }

  async submitNew(e) {
    const container = e.currentTarget.closest("dialog").querySelector("[data-form-action]")
    if (!container) return
    const data = new FormData()
    container.querySelectorAll("[name]").forEach(el => data.append(el.name, el.value))
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrf) data.append("authenticity_token", csrf)

    try {
      const resp = await fetch(container.dataset.formAction, {
        method: "POST",
        body: data,
        headers: { "Accept": "text/html" },
        credentials: "same-origin"
      })
      if (resp.ok || resp.redirected) {
        this.dialogTarget.close()
        this.inputTarget.value = ""
        this._doSearch()
      }
    } catch (_) {}
  }

  backdropClose(e) {
    if (e.target === this.dialogTarget) this.closeNew()
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
