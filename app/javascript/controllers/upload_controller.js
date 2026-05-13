import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "input", "fileList", "submit"]

  connect() {
    this.files = []
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
    event.preventDefault()
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
    this.render()
    this.updateInput()
  }

  removeFile(event) {
    const idx = parseInt(event.currentTarget.dataset.index)
    this.files.splice(idx, 1)
    this.render()
    this.updateInput()
  }

  updateInput() {
    const dt = new DataTransfer()
    for (const f of this.files) {
      dt.items.add(f)
    }
    this.inputTarget.files = dt.files
  }

  render() {
    if (this.files.length === 0) {
      this.fileListTarget.innerHTML = ""
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

    for (const file of this.files) {
      this.setStatus(file.name, "uploading...")

      const fd = new FormData()
      fd.append("stamp[original_file]", file)
      fd.append("stamp[batch_started_at]", batchStartedAt)
      fd.append("stamp[batch_size]", batchSize)
      if (csrf) fd.append("authenticity_token", csrf)

      try {
        const resp = await fetch(this.element.action, {
          method: "POST",
          body: fd,
          headers: { "Accept": "text/vnd.turbo-stream.html, text/html, text/plain" },
          credentials: "same-origin"
        })
        if (resp.ok || resp.redirected) {
          success++
          this.setStatus(file.name, "✓ uploaded")
        } else {
          const text = await resp.text()
          let msg = "failed"
          const m = text.match(/class="error"[^>]*>([^<]+)/)
          if (m) msg = m[1].trim()
          this.setStatus(file.name, `✗ ${msg}`)
          failure++
        }
      } catch {
        this.setStatus(file.name, "✗ network error")
        failure++
      }
    }

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
