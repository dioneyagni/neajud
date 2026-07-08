import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    itemUuid: String,
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
    if (btn) {
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
            setTimeout(() => {
              btn.textContent = "Salvar"
              btn.disabled = false
            }, 1500)
          } else {
            btn.textContent = "Erro!"
            setTimeout(() => {
              btn.textContent = "Salvar"
              btn.disabled = false
            }, 3000)
          }
        }
      })
      .catch(() => {
        if (btn) {
          btn.textContent = "Erro!"
          setTimeout(() => {
            btn.textContent = "Salvar"
            btn.disabled = false
          }, 3000)
        }
      })
  }
}
