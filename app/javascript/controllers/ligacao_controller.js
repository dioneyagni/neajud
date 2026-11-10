import { Controller } from "@hotwired/stimulus"

// A ligação's form (rede editável 2/2a): adds and takes out ligante rows,
// lets a situação have its own ligantes or go back to the usual ones, and
// opens the trash's confirmation. Each list says its field prefix in
// data-nome; a row is the server's template with the names filled in.
export default class extends Controller {
  static targets = ["modelo", "dialogo"]

  connect() {
    this.boundFecharPeloFundo = this.fecharPeloFundo.bind(this)
  }

  adicionar(event) {
    const lista = event.currentTarget.closest("[data-ligantes]")
    lista.querySelector("[data-lista]").append(this.linha(lista.dataset.nome))
  }

  tirar(event) {
    event.currentTarget.closest(".ligacao-ligante").remove()
  }

  // The situação gets its own ligantes, starting with an empty row.
  mudar(event) {
    const situacao = event.currentTarget.closest("[data-situacao]")
    situacao.querySelector("[data-os-de-cima]").hidden = true
    situacao.querySelector("[data-proprios]").hidden = false
    situacao.querySelector("[data-lista]").append(this.linha(situacao.dataset.nome))
  }

  // No rows sent: the situação keeps the usual ligantes.
  voltar(event) {
    const situacao = event.currentTarget.closest("[data-situacao]")
    situacao.querySelector("[data-lista]").replaceChildren()
    situacao.querySelector("[data-os-de-cima]").hidden = false
    situacao.querySelector("[data-proprios]").hidden = true
  }

  abrirLixeira() {
    this.dialogoTarget.showModal()
    this.dialogoTarget.addEventListener("click", this.boundFecharPeloFundo)
  }

  fecharLixeira() {
    this.dialogoTarget.close()
    this.dialogoTarget.removeEventListener("click", this.boundFecharPeloFundo)
  }

  fecharPeloFundo(event) {
    if (event.target !== this.dialogoTarget) return
    this.fecharLixeira()
  }

  linha(nome) {
    const linha = this.modeloTarget.content.firstElementChild.cloneNode(true)
    linha.querySelectorAll("[data-campo]").forEach((campo) => { campo.name = `${nome}[][${campo.dataset.campo}]` })
    return linha
  }
}
