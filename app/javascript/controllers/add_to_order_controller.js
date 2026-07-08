import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "preview", "filename", "client",
                    "materialHidden", "gradeContainer",
                    "submitBtn", "errorContainer"]

  static values = {
    arteUuid: String,
    arteFilename: String,
    arteClient: String,
    arteClientId: String,
    artePreview: String,
    tamanhos: Array
  }

  connect() {
    this.boundClose = this.backdropClose.bind(this)
  }

  open(e) {
    const btn = e.currentTarget
    this.arteUuidValue = btn.dataset.addToOrderArteUuid
    this.arteFilenameValue = btn.dataset.addToOrderArteFilename
    this.arteClientValue = btn.dataset.addToOrderArteClient || ""
    this.artePreviewValue = btn.dataset.addToOrderArtePreview || ""
    this.arteClientIdValue = btn.dataset.addToOrderArteClientId || ""

    let tamanhos = []
    try {
      tamanhos = JSON.parse(btn.dataset.addToOrderTamanhos || "[]")
    } catch {}
    this.tamanhosValue = tamanhos

    this._updateComboboxUrl()
    this._populateModal()
    this.modalTarget.showModal()
    this.modalTarget.addEventListener("click", this.boundClose)
  }

  close() {
    this.modalTarget.close()
    this.modalTarget.removeEventListener("click", this.boundClose)
    this._reset()
  }

  backdropClose(e) {
    if (e.target !== this.modalTarget) return
    this.close()
  }

  _updateComboboxUrl() {
    const materialField = this.modalTarget.querySelector("[data-controller='combobox']")
    if (!materialField) return
    let searchUrl = "/materiais/search"
    let registerUrl = "/materiais/new"
    if (this.arteClientIdValue) {
      const qs = `client_id=${encodeURIComponent(this.arteClientIdValue)}`
      searchUrl += `?${qs}`
      registerUrl += `?${qs}`
    }
    materialField.dataset.comboboxSearchUrlValue = searchUrl
    materialField.dataset.comboboxRegisterUrlValue = registerUrl
  }

  submit(e) {
    e.preventDefault()
    this.submitBtnTarget.disabled = true
    this.errorContainerTarget.classList.add("add-to-order-error--hidden")

    const formData = new FormData()
    formData.append("arquivo_uuid", this.arteUuidValue)

    const materialId = this.materialHiddenTarget.value
    if (materialId) {
      formData.append("materia_prima_id", materialId)
    }

    const gradeInputs = this.gradeContainerTarget.querySelectorAll(".add-to-order-grade-input")
    gradeInputs.forEach(input => {
      const val = parseInt(input.value, 10)
      if (val > 0) {
        formData.append(`grade[${input.dataset.tamanhoNome}]`, val)
      }
    })

    const qtdTotal = this.gradeContainerTarget.querySelector(".add-to-order-qtd-total")
    if (qtdTotal) {
      const val = parseInt(qtdTotal.value, 10)
      if (val > 0) {
        formData.append("grade[_total]", val)
      }
    }

    const csrfMeta = document.querySelector("[name='csrf-token']")
    const headers = { "Accept": "application/json" }
    if (csrfMeta) {
      headers["X-CSRF-Token"] = csrfMeta.content
    }

    fetch("/pedidos/adicionar_item", {
      method: "POST",
      headers: headers,
      body: formData
    })
      .then(r => r.json())
      .then(data => {
        if (data.ok) {
          document.dispatchEvent(new CustomEvent("pedido:item-added", {
            detail: { total_itens: data.total_itens }
          }))
          this.close()
        } else {
          this._showError(data.error || "Erro ao adicionar item")
        }
      })
      .catch(err => {
        this._showError(err.message || "Erro de conexão")
      })
      .finally(() => {
        this.submitBtnTarget.disabled = false
      })
  }

  _populateModal() {
    if (this.hasPreviewTarget && this.artePreviewValue) {
      this.previewTarget.innerHTML = `<img src="${this.artePreviewValue}" alt="${this.arteFilenameValue}" style="max-width:200px; max-height:200px; border-radius:4px;">`
    } else if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = `<span style="color:var(--text-muted); font-size:0.85rem;">Sem preview</span>`
    }

    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = this.arteFilenameValue
    }

    if (this.hasClientTarget) {
      this.clientTarget.textContent = this.arteClientValue || "Sem cliente"
      this.clientTarget.style.color = this.arteClientValue ? "inherit" : "var(--text-muted)"
    }

    this._renderGradeGrid()
  }

  _renderGradeGrid() {
    if (!this.hasGradeContainerTarget) return

    if (this.tamanhosValue.length > 0) {
      this.gradeContainerTarget.innerHTML = `
        <div class="grade-cards">
          ${this.tamanhosValue.map(t => `
            <div class="grade-card">
              <span class="grade-card-label">${t.nome}</span>
              <input type="number" class="grade-card-input add-to-order-grade-input" data-tamanho-nome="${t.nome}" value="0" min="0" step="1">
            </div>
          `).join("")}
        </div>
      `
    } else {
      this.gradeContainerTarget.innerHTML = `
        <div class="add-to-order-qtd-row">
          <label>Quantidade:</label>
          <input type="number" class="add-to-order-qtd-total" value="1" min="0" step="1">
        </div>
      `
    }
  }

  _showError(msg) {
    this.errorContainerTarget.textContent = msg
    this.errorContainerTarget.classList.remove("add-to-order-error--hidden")
  }

  _reset() {
    if (this.hasMaterialHiddenTarget) {
      this.materialHiddenTarget.value = ""
    }
    const comboboxInput = this.modalTarget.querySelector(".combobox-input")
    if (comboboxInput) comboboxInput.value = ""
    this.errorContainerTarget.classList.add("add-to-order-error--hidden")
    this.submitBtnTarget.disabled = false
  }

}
