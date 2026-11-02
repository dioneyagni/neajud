import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The construção's form (Dublagem 3/5): any change sends the form as it is
// to /construcoes/montar, which answers the form again — each layer's
// options from the network and the price — as a turbo-stream; nothing is
// saved until "Salvar construção". A button's data-acao asks to add or remove
// a layer. Only the latest answer replaces the form (the combobox's stale
// answer, #178).
// Usage: <form data-controller="construcao" data-construcao-url-value="/construcoes/montar" data-construcao-uuid-value="…">
export default class extends Controller {
  static values = { url: String, uuid: String }

  connect() {
    this.ultimaMontagem = 0
  }

  montar(event) {
    const corpo = new FormData(this.element)
    // The edit form's PATCH would route to PATCH /construcoes/montar.
    corpo.delete("_method")
    if (this.uuidValue) corpo.append("construcao_uuid", this.uuidValue)
    if (event.currentTarget.dataset.acao) corpo.append("acao", event.currentTarget.dataset.acao)
    const montagem = ++this.ultimaMontagem
    const csrf = document.querySelector("meta[name='csrf-token']")?.content || ""
    fetch(this.urlValue, { method: "POST", headers: { "Accept": "text/vnd.turbo-stream.html", "X-CSRF-Token": csrf }, body: corpo })
      .then(resposta => resposta.text())
      .then(html => {
        if (montagem === this.ultimaMontagem) Turbo.renderStreamMessage(html)
      })
  }
}
