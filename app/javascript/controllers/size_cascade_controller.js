import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { moldeId: Number, modeloId: Number, clientId: Number }
  static targets = ["pecaSelect", "tamanhoSelect", "tamanhoId", "saveBtn"]

  connect() {
    if (this.moldeIdValue) {
      this.fetchPecas()
    }
  }

  baseParams() {
    const params = new URLSearchParams()
    params.set("molde_id", this.moldeIdValue)
    if (this.hasModeloIdValue && this.modeloIdValue) {
      params.set("modelo_id", this.modeloIdValue)
    }
    if (this.hasClientIdValue && this.clientIdValue) {
      params.set("client_id", this.clientIdValue)
    }
    return params
  }

  cascadeUrl(base) {
    return `${base}?${this.baseParams()}`
  }

  fetchPecas() {
    fetch(this.cascadeUrl("/pecas/for_cascade"))
      .then(r => r.json())
      .then(pecas => {
        this.pecaSelectTarget.innerHTML = "<option value=''>Select a piece...</option>" +
          pecas.map(p => `<option value="${p.id}">${p.nome}</option>`).join("")
      })
  }

  onPecaChange() {
    const pecaId = this.pecaSelectTarget.value
    this.tamanhoSelectTarget.innerHTML = "<option value=''>Select a size...</option>"
    this.tamanhoIdTarget.value = ""
    this.saveBtnTarget.disabled = true
    if (!pecaId) return

    const params = this.baseParams()
    params.set("peca_id", pecaId)
    fetch(`/tamanhos/for_cascade?${params}`)
      .then(r => r.json())
      .then(tamanhos => {
        this.tamanhoSelectTarget.innerHTML = "<option value=''>Select a size...</option>" +
          tamanhos.map(t => {
            const dim = t.width && t.height ? `${t.width}×${t.height} mm` : ""
            const label = dim ? `${t.nome} (${dim})` : t.nome
            return `<option value="${t.id}">${label}</option>`
          }).join("")
      })
  }

  onTamanhoChange() {
    const id = this.tamanhoSelectTarget.value
    this.tamanhoIdTarget.value = id
    this.saveBtnTarget.disabled = !id
  }
}
