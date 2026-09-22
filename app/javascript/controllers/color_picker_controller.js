import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "name", "dialog"]

  select(event) {
    this.element.querySelectorAll(".color-swatch").forEach(s => s.classList.remove("selected"))
    event.currentTarget.classList.add("selected")
    this.inputTarget.value = event.currentTarget.dataset.id
    this.nameTarget.textContent = event.currentTarget.title
  }

  openNew() {
    this.dialogTarget.showModal()
  }

  closeNew() {
    this.dialogTarget.close()
  }

  // New colors only exist via this dialog (no CorMaterial seed data — see
  // AGENTS.md). Full reload (not a re-fetch like group-select) because the
  // swatch grid is rendered server-side from @cores on page load.
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
      if (resp.ok || resp.redirected) window.location.reload()
    } catch (_) {}
  }

  backdropClose(e) {
    if (e.target === this.dialogTarget) this.closeNew()
  }
}
