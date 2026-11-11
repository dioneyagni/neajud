import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The construção's form (Dublagem 3/5): any change sends the form as it is
// to /construcoes/montar, which answers the form again — each layer's
// options from the network and the price — as a turbo-stream; nothing is
// saved until "Salvar construção". A button's data-acao asks to add or remove
// a layer. Only the latest answer replaces the form (the combobox's stale
// answer, #178). Dublagem 5b1b: a card's "Adicionar à rede" creates the
// ligação (JSON, the fields have no name so the form never sends them) and
// asks for the form again; a refusal shows inside the card.
// Usage: <form data-controller="construcao" data-construcao-url-value="/construcoes/montar" data-construcao-uuid-value="…">
export default class extends Controller {
  static values = { url: String, uuid: String }

  connect() {
    this.ultimaMontagem = 0
  }

  async adicionarARede(event) {
    const botao = event.currentTarget
    const caixa = botao.closest("[data-falta-rede]")
    const corpo = new FormData()
    corpo.append("origem", "construcao")
    corpo.append("ligacao[grupo_a_uuid]", botao.dataset.grupoA)
    corpo.append("ligacao[grupo_b_uuid]", botao.dataset.grupoB)
    corpo.append("ligacao[dubla]", caixa.querySelector("[data-rede-momento]").value)
    corpo.append("ligacao[ligantes][][grupo_uuid]", caixa.querySelector("[data-rede-ligante]").value)
    // Q2a: made in the middle of a construção, for whoever keeps the network to review.
    for (const campo of ["dubla", "ligantes"]) corpo.append("ligacao[a_confirmar][]", campo)
    botao.disabled = true
    const resposta = await fetch(botao.dataset.url, { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": this.csrf() }, body: corpo })
    const dados = await resposta.json().catch(() => ({ ok: false, error: `the server answered ${resposta.status}` }))
    botao.disabled = false
    if (!dados.ok) return (caixa.querySelector("[data-erro-rede]").textContent = dados.error)
    // After the await the event no longer has its currentTarget.
    this.montar({ currentTarget: botao })
  }

  csrf() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  montar(event) {
    const corpo = new FormData(this.element)
    // The edit form's PATCH would route to PATCH /construcoes/montar.
    corpo.delete("_method")
    if (this.uuidValue) corpo.append("construcao_uuid", this.uuidValue)
    if (event.currentTarget.dataset.acao) corpo.append("acao", event.currentTarget.dataset.acao)
    const montagem = ++this.ultimaMontagem
    fetch(this.urlValue, { method: "POST", headers: { "Accept": "text/vnd.turbo-stream.html", "X-CSRF-Token": this.csrf() }, body: corpo })
      .then(resposta => resposta.text())
      .then(html => {
        if (montagem === this.ultimaMontagem) Turbo.renderStreamMessage(html)
      })
  }
}
