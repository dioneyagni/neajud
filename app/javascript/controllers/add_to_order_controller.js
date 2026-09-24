import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "preview", "filename", "client",
                    "materialHidden", "gradeContainer",
                    "submitBtn", "errorContainer", "pecasContainer"]

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
    this._loadPecas()
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

    this._uncheckedPecaUuids().forEach(uuid => formData.append("excluir_arquivos[]", uuid))

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

  // Pieces of the arte's modelo. A response for an arte other than the one
  // currently open (modal reopened before it arrived) is dropped.
  _loadPecas() {
    if (!this.hasPecasContainerTarget) return
    const uuid = this.arteUuidValue
    this._showPecasMessage("Carregando peças…")
    fetch(`/arquivos/${encodeURIComponent(uuid)}/composicao`, { headers: { "Accept": "application/json" } })
      .then(r => r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`)))
      .then(data => { if (uuid === this.arteUuidValue) this._renderPecas(data.pecas || []) })
      .catch(() => { if (uuid === this.arteUuidValue) this._showPecasMessage("Não foi possível carregar as peças do modelo.") })
  }

  // A single-piece arte needs no piece picker.
  _renderPecas(pecas) {
    const container = this.pecasContainerTarget
    container.replaceChildren()
    container.hidden = pecas.length < 2
    if (container.hidden) return
    const title = document.createElement("label")
    title.textContent = "Peças do modelo:"
    const grid = document.createElement("div")
    grid.className = "add-to-order-pecas-grid"
    pecas.forEach(peca => grid.appendChild(this._pecaCard(peca)))
    container.append(title, grid)
  }

  _pecaCard(peca) {
    const card = document.createElement("div")
    card.className = "add-to-order-peca" + (peca.pendente ? " add-to-order-peca--pendente" : "")
    card.appendChild(this._pecaThumb(peca))
    const name = document.createElement("span")
    name.className = "add-to-order-peca-nome"
    name.textContent = peca.peca_nome || "Sem peça"
    card.appendChild(name)
    card.appendChild(peca.pendente ? this._pendingBadge() : this._pecaCheckbox(peca, card))
    return card
  }

  _pecaThumb(peca) {
    if (!peca.preview_url) {
      const empty = document.createElement("div")
      empty.className = "add-to-order-peca-thumb add-to-order-peca-thumb--empty"
      empty.textContent = peca.pendente ? "sem arte" : "sem preview"
      return empty
    }
    const img = document.createElement("img")
    img.className = "add-to-order-peca-thumb"
    img.src = peca.preview_url
    img.alt = peca.filename || ""
    return img
  }

  _pendingBadge() {
    const badge = document.createElement("span")
    badge.className = "add-to-order-peca-pendente"
    badge.textContent = "Pendente"
    badge.title = "Sem arte: precisa ser completada antes de confirmar o pedido"
    return badge
  }

  // Unchecked = the pedido goes to production without this piece.
  _pecaCheckbox(peca, card) {
    const label = document.createElement("label")
    label.className = "add-to-order-peca-toggle"
    const input = document.createElement("input")
    input.type = "checkbox"
    input.checked = true
    input.className = "add-to-order-peca-check"
    input.dataset.arquivoUuid = peca.arquivo_uuid
    input.addEventListener("change", () => card.classList.toggle("add-to-order-peca--excluida", !input.checked))
    label.append(input, " incluir")
    return label
  }

  _uncheckedPecaUuids() {
    if (!this.hasPecasContainerTarget) return []
    return Array.from(this.pecasContainerTarget.querySelectorAll(".add-to-order-peca-check:not(:checked)"))
      .map(input => input.dataset.arquivoUuid)
  }

  _showPecasMessage(text) {
    const container = this.pecasContainerTarget
    const message = document.createElement("span")
    message.className = "add-to-order-pecas-message"
    message.textContent = text
    container.replaceChildren(message)
    container.hidden = false
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
    if (this.hasPecasContainerTarget) {
      this.pecasContainerTarget.replaceChildren()
      this.pecasContainerTarget.hidden = true
    }
  }

}
