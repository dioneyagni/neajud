import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    searchUrl: String,
    displayField: { type: String, default: "name" },
    extraFields: { type: String, default: "" },
    registerLabel: { type: String, default: "Register new" },
    registerUrl: { type: String, default: "" }
  }

  connect() {
    this.selected = false
  }

  search() {
    const q = this.input.value.trim()
    if (this.selected) { this.selected = false; return }

    fetch(`${this.searchUrlValue}?q=${encodeURIComponent(q)}`)
      .then(r => r.json())
      .then(items => {
        const extraFieldNames = this.extraFieldsValue ? this.extraFieldsValue.split(",") : []
        this.results.innerHTML = items.map(item => {
          const displayName = item[this.displayFieldValue] || item.nome || item.name || ""
          const extras = extraFieldNames.map(f => item[f]).filter(v => v).join(" — ")
          const label = extras ? `${displayName} (${extras})` : displayName
          return `
            <div class="combobox-option" data-id="${item.id}" data-name="${displayName.replace(/"/g, '&quot;')}" data-action="click->combobox#select">
              <strong>${this._highlight(displayName, q)}</strong>
              ${extras ? `<span class="combobox-option-detail">${this._highlight(extras, q)}</span>` : ""}
            </div>
          `
        }).join("") + `
          <div class="combobox-option combobox-option-new" data-action="click->combobox#openNew">
            + ${this.registerLabelValue}
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
    if (this.registerUrlValue) {
      window.location.href = this.registerUrlValue
      return
    }
    const dialogEl = this.element.closest("[data-controller*='dialog']")
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
    const hiddenInputs = this.element.querySelectorAll('input[type=hidden]')
    return Array.from(hiddenInputs).find(i => i.name !== "authenticity_token" && i.name !== "_method") || hiddenInputs[0]
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