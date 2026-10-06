import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Saves a pedido item's grade (PATCH atualizar_item). Once saved the page
// morph-refreshes, so the matrix resolves the new numbers (which DXF size,
// which file, what is missing) and the side panel recounts (Etapa 1.2, 3/3
// parte 3a).

export default class extends Controller {
  static values = {
    saveUrl: String
  }

  save() {
    const formData = new FormData()

    this.element.querySelectorAll(".grade-qtd-input").forEach(input => {
      const val = parseInt(input.value, 10)
      formData.append(`grade[${input.dataset.tamanhoNome}]`, isNaN(val) ? 0 : val)
    })

    const csrfMeta = document.querySelector("[name='csrf-token']")
    const headers = { "Accept": "application/json" }
    if (csrfMeta) {
      headers["X-CSRF-Token"] = csrfMeta.content
    }

    const btn = this.element.querySelector(".grade-save-btn")
    this._showError("")
    if (btn) {
      this.rotuloOriginal ||= btn.textContent
      btn.disabled = true
      btn.textContent = "Salvando..."
    }

    fetch(this.saveUrlValue, {
      method: "PATCH",
      headers: headers,
      body: formData
    })
      .then(r => r.json())
      .then(data => {
        if (btn) {
          if (data.ok) {
            btn.textContent = "Salvo"
            Turbo.visit(window.location.href, { action: "replace" })
          } else {
            this._showError(data.error)
            btn.textContent = "Erro!"
            setTimeout(() => {
              btn.textContent = this.rotuloOriginal
              btn.disabled = false
            }, 3000)
          }
        }
      })
      .catch(() => {
        if (btn) {
          btn.textContent = "Erro!"
          setTimeout(() => {
            btn.textContent = this.rotuloOriginal
            btn.disabled = false
          }, 3000)
        }
      })
  }

  // Server's reason (e.g. "Quantidade total 0 — use Remover…") next to Salvar.
  _showError(message) {
    let box = this.element.querySelector(".grade-save-error")
    if (!box) {
      box = document.createElement("p")
      box.className = "grade-save-error"
      this.element.querySelector(".pedido-item-actions")?.appendChild(box)
    }
    box.textContent = message || ""
    box.hidden = !message
  }
}
