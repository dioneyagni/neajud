import { Controller } from "@hotwired/stimulus"
import ConferenciaDoUpload from "controllers/conferencia_upload"

export default class extends Controller {
  static targets = ["dropzone", "input", "fileList", "submit", "tipo"]
  static values = { fieldName: { type: String, default: "arquivo[original_file]" }, agrupamentoUrl: String, artesUrl: String }

  connect() {
    this.files = []
    this.textoDoBotao = this.submitTarget.value
  }

  dragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("dragover")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("dragover")
  }

  click(event) {
    if (event.target.closest("label")) return
    this.inputTarget.click()
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("dragover")
    this.addFiles([...event.dataTransfer.files])
  }

  fileSelected(event) {
    this.addFiles([...event.target.files])
  }

  addFiles(newFiles) {
    const allowed = (this.element.dataset.allowedExtensions || ".tif,.tiff,.psd,.ai,.eps,.cdr,.pdf,.dxf,.svg,.dwg,.cad").split(",")
    for (const f of newFiles) {
      const ext = "." + f.name.split(".").pop().toLowerCase()
      if (allowed.includes(ext)) {
        if (!this.files.some(existing => existing.name === f.name && existing.size === f.size)) {
          this.files.push(f)
        }
      }
    }
    this.updateInput()
    this.agrupar()
  }

  removeFile(event) {
    const idx = parseInt(event.currentTarget.dataset.index)
    this.files.splice(idx, 1)
    this.updateInput()
    this.agrupar()
  }

  // Etapa 1.2 (2/3, parte 3): ask the server how the chosen files group into
  // artes; the conference shows only when something groups (decided 05/10/2026).
  agrupar() {
    this.conferencia = null
    this.render()
    if (this.files.length === 0 || !this.hasAgrupamentoUrlValue) return

    const pedido = this.buscarAgrupamento()
    this.agrupando = pedido
    pedido.then(resposta => {
      // Drawn again only when the conference shows: redrawing the plain list
      // would swap elements someone may be about to click.
      if (this.agrupando !== pedido || !resposta?.conferir) return
      this.conferencia = new ConferenciaDoUpload(resposta, s => this.escapeHtml(s), this.tipoEscolhido())
      this.render()
    })
  }

  async buscarAgrupamento() {
    try {
      const resp = await fetch(this.agrupamentoUrlValue, {
        method: "POST", headers: this.cabecalhosJson(), credentials: "same-origin",
        body: JSON.stringify({ arquivos: this.files.map(f => ({ nome: f.name, bytes: f.size })) })
      })
      return resp.ok ? await resp.json() : null
    } catch {
      return null
    }
  }

  // Etapa 2.5a: the kind of work chosen for the whole upload.
  tipoEscolhido() {
    return this.hasTipoTarget ? this.tipoTarget.value : "calcado"
  }

  mudarTipo() {
    if (this.conferencia?.todosDoTipo(this.tipoEscolhido())) this.render()
  }

  conferir(event) {
    if (this.conferencia?.aplicar(event)) this.render()
  }

  async criarArte(tipo) {
    try {
      const resp = await fetch(this.artesUrlValue, { method: "POST", headers: this.cabecalhosJson(), credentials: "same-origin", body: JSON.stringify({ tipo }) })
      return resp.ok ? (await resp.json()).uuid : null
    } catch {
      return null
    }
  }

  cabecalhosJson() {
    return { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
  }

  updateInput() {
    const dt = new DataTransfer()
    for (const f of this.files) {
      dt.items.add(f)
    }
    this.inputTarget.files = dt.files
  }

  render() {
    this.submitTarget.value = this.textoDoBotao
    if (this.files.length === 0) {
      this.fileListTarget.innerHTML = ""
      return
    }
    if (this.conferencia) {
      this.fileListTarget.innerHTML = this.conferencia.html(this.files)
      this.submitTarget.value = `Upload ${this.files.length} files in ${this.conferencia.totalDeArtes} artes`
      return
    }

    this.fileListTarget.innerHTML = this.files.map((f, i) =>
      `<div class="upload-file" data-index="${i}">
        <span class="upload-file-name">${this.escapeHtml(f.name)}</span>
        <span class="upload-file-size">${(f.size / 1024).toFixed(0)} KB</span>
        <span class="upload-file-status"></span>
        <button type="button" class="upload-file-remove" data-action="click->upload#removeFile" data-index="${i}">×</button>
      </div>`
    ).join("")
  }

  async submit(event) {
    event.preventDefault()
    if (this.files.length === 0) return

    this.submitTarget.disabled = true
    this.submitTarget.value = "Uploading..."

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const batchStartedAt = new Date().toISOString()
    const batchSize = this.files.length

    let success = 0
    let failure = 0
    const enviados = []
    await this.agrupando
    const plano = this.conferencia ? await this.conferencia.plano(tipo => this.criarArte(tipo)) : this.files.map((_, indice) => ({ indice, campos: { tipo: this.tipoEscolhido() } }))

    for (const { indice, campos } of plano) {
      const file = this.files[indice]
      this.setStatus(file.name, "uploading...")

      const fd = new FormData()
      fd.append(this.fieldNameValue, file)
      for (const [campo, valor] of Object.entries(campos)) {
        if (valor) fd.append(`arquivo[${campo}]`, valor)
      }
      fd.append("arquivo[batch_started_at]", batchStartedAt)
      fd.append("arquivo[batch_size]", batchSize)
      if (csrf) fd.append("authenticity_token", csrf)

      try {
        const resp = await fetch(this.element.action, {
          method: "POST",
          body: fd,
          headers: { "Accept": "application/json" },
          credentials: "same-origin"
        })
        const corpo = await resp.json().catch(() => ({}))
        if (resp.ok) {
          success++
          enviados.push(corpo.uuid)
          this.setStatus(file.name, "✓ uploaded")
        } else {
          this.setStatus(file.name, `✗ ${corpo.error || "failed"}`)
          failure++
        }
      } catch {
        this.setStatus(file.name, "✗ network error")
        failure++
      }
    }

    // The created files' uuids: E2E waits for these, not for a card by name.
    this.element.dataset.uploadEnviados = enviados.join(" ")
    this.submitTarget.value = `Upload complete (${success} ok, ${failure} failed)`
    setTimeout(() => window.location.reload(), 1500)
  }

  setStatus(fileName, text) {
    const items = this.fileListTarget.querySelectorAll(".upload-file")
    for (const el of items) {
      if (el.querySelector(".upload-file-name")?.textContent === fileName) {
        el.querySelector(".upload-file-status").textContent = text
        break
      }
    }
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
