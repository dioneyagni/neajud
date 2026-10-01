import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // The arte's molde (uuid): the server lists the pieces and sizes of that
  // molde's cortes (Arquivo.cortes_do_molde). Filtering by the category +
  // client listed nothing once a molde changed category, and could list
  // another molde's cortes (01/10/2026).
  static values = { moldeUuid: String }
  static targets = ["pecaSelect", "tamanhoSelect", "tamanhoUuid", "saveBtn"]

  connect() {
    if (this.moldeUuidValue) {
      this.fetchPecas()
    }
  }

  baseParams() {
    return new URLSearchParams({ molde_uuid: this.moldeUuidValue })
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
    const pecaUuid = this.pecaSelectTarget.value
    this.tamanhoSelectTarget.innerHTML = "<option value=''>Select a size...</option>"
    this.tamanhoUuidTarget.value = ""
    this.saveBtnTarget.disabled = true
    if (!pecaUuid) return

    const params = this.baseParams()
    params.set("peca_uuid", pecaUuid)
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
    const uuid = this.tamanhoSelectTarget.value
    this.tamanhoUuidTarget.value = uuid
    this.saveBtnTarget.disabled = !uuid
  }
}
