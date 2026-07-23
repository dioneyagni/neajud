import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "toolbar", "count", "deleteButton"]
  static values = { selectedCount: { type: Number, default: 0 } }

  connect() {
    this.selectedCountValue = 0
  }

  toggle(e) {
    if (e.target.checked) {
      this.selectedCountValue++
    } else {
      this.selectedCountValue--
      if (this.hasSelectAllTarget) this.selectAllTarget.checked = false
    }
    this.updateToolbar()
  }

  toggleAll(e) {
    const checked = e.target.checked
    this.checkboxTargets.forEach(cb => {
      cb.checked = checked
    })
    this.selectedCountValue = checked ? this.checkboxTargets.length : 0
    this.updateToolbar()
  }

  batchDelete() {
    const ids = this.checkboxTargets.filter(cb => cb.checked).map(cb => cb.value)
    if (ids.length === 0) return
    if (!confirm(`Delete ${ids.length} arquivo(s)?`)) return

    this.deleteButtonTarget.disabled = true
    this.deleteButtonTarget.textContent = "Deleting..."

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    const url = this.data.get("delete-url")
    fetch(url, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ ids: ids })
    }).then(async r => {
      if (!r.ok) throw new Error("Delete failed")
      window.location.reload()
    }).catch(e => {
      console.error("[batch-select] error:", e.message)
      alert("Failed to delete some files. Please try again.")
      this.deleteButtonTarget.disabled = false
      this.deleteButtonTarget.textContent = "Delete Selected"
    })
  }

  updateToolbar() {
    if (this.selectedCountValue > 0) {
      this.toolbarTarget.classList.remove("batch-toolbar--hidden")
      this.countTarget.textContent = `${this.selectedCountValue} selected`
    } else {
      this.toolbarTarget.classList.add("batch-toolbar--hidden")
      this.countTarget.textContent = "0 selected"
    }
  }
}
