import { Controller } from "@hotwired/stimulus"

// The pedido page's "add an arte" (Etapa 1.2, 3/3; decided 05/10/2026):
// molde → referência → the artes, each with its preview. Choosing one opens
// the same "Adicionar ao Pedido" modal as the gallery (add-to-order).
export default class extends Controller {
  static targets = ["molde", "referencia", "artes"]
  static values = { url: String }

  escolherMolde() {
    this.referenciaTarget.innerHTML = '<option value="">All references</option>'
    this.referenciaTarget.hidden = !this.moldeTarget.value
    this.carregar(true)
  }

  escolherReferencia() {
    this.carregar(false)
  }

  async carregar(comReferencias) {
    this.artesTarget.innerHTML = ""
    if (!this.moldeTarget.value) return

    const params = new URLSearchParams({ molde_uuid: this.moldeTarget.value, referencia_uuid: this.referenciaTarget.value })
    const resposta = await fetch(`${this.urlValue}?${params}`, { headers: { "Accept": "application/json" } })
    if (!resposta.ok) return

    const dados = await resposta.json()
    if (comReferencias) this.referenciaTarget.insertAdjacentHTML("beforeend", dados.referencias.map(r => `<option value="${r.uuid}">${this.escapar(r.nome)}</option>`).join(""))
    this.artesTarget.innerHTML = dados.artes.length ? dados.artes.map(a => this.card(a)).join("") : '<p class="gallery-empty">No artes in this molde yet.</p>'
  }

  card(arte) {
    const preview = arte.preview ? `<img class="pedido-adicionar-thumb" src="${arte.preview}" alt="" loading="lazy">` : '<div class="pedido-adicionar-thumb pedido-adicionar-thumb--vazio">sem preview</div>'
    return `<div class="pedido-adicionar-arte" data-arquivo-uuid="${arte.arquivo_uuid}">
      ${preview}
      <strong>${this.escapar(arte.titulo)}</strong>
      <span>${this.escapar(arte.resumo || arte.filename)}</span>
      <button type="button" class="btn btn-sm btn-primary" data-action="click->add-to-order#open"
              data-add-to-order-arte-uuid="${arte.arquivo_uuid}" data-add-to-order-arte-filename="${this.escapar(arte.titulo)}"
              data-add-to-order-arte-client="${this.escapar(arte.client || "")}" data-add-to-order-arte-client-uuid="${arte.client_uuid || ""}"
              data-add-to-order-arte-preview="${arte.preview || ""}" data-add-to-order-tamanhos="${this.escapar(JSON.stringify(arte.tamanhos))}">Adicionar</button>
    </div>`
  }

  escapar(texto) {
    const div = document.createElement("div")
    div.textContent = texto
    return div.innerHTML.replace(/"/g, "&quot;")
  }
}
