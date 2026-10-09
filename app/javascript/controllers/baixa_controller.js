import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A production stage's baixa (Etapa 2.2, 2/3; decided 07/10/2026): "Baixa"
// opens the measure field next to the download; saving checks it against
// what the files expect. Outside the dono's band the server answers with a
// warning — correct the value, or "Confirmar assim mesmo" saves it marked.
// Once saved the page reloads (the line shows ✓ and who did it).
// Conferência (Etapa 2.2, 4/4; decided 09/10/2026): a count that came short
// asks for each line's count, with Impressão and Corte checked to redo — the
// conferente fixes the short ones, unchecks what doesn't need redoing and
// confirms; the missing pieces go to the pedido's open reposição.
export default class extends Controller {
  static targets = ["abrir", "editor", "medida", "mensagem", "confirmar", "contagem"]
  static values = { url: String, etapa: String, nivel: String, alvo: String }

  abrir() {
    this.abrirTarget.hidden = true
    this.editorTarget.hidden = false
    this.medidaTarget.focus()
  }

  cancelar() {
    this.editorTarget.hidden = true
    this.abrirTarget.hidden = false
    this.limpar()
  }

  // A new value asks again: the warning was about the previous one.
  editou() {
    this.limpar()
  }

  salvar(event) {
    event?.preventDefault()
    this.enviar(false)
  }

  confirmarAssim() {
    this.enviar(true)
  }

  enviar(confirmar) {
    const body = new FormData()
    const contagens = this.contagemTarget.querySelectorAll("input[data-chave]")
    const medida = contagens.length ? [...contagens].reduce((soma, input) => soma + (parseInt(input.value, 10) || 0), 0) : this.medidaTarget.value
    Object.entries({ etapa: this.etapaValue, nivel: this.nivelValue, alvo: this.alvoValue, medida, confirmar: confirmar ? "1" : "0" })
      .forEach(([campo, valor]) => body.append(campo, valor))
    contagens.forEach(input => {
      body.append(`contagens[${input.dataset.chave}]`, input.value)
      const refazer = [...this.contagemTarget.querySelectorAll(`input[data-refazer][data-linha="${CSS.escape(input.dataset.chave)}"]:checked`)].map(c => c.value)
      body.append(`refazer[${input.dataset.chave}]`, refazer.join(","))
    })
    const csrf = document.querySelector("meta[name='csrf-token']")?.content || ""
    fetch(this.urlValue, { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": csrf }, body })
      .then(r => r.json().catch(() => ({ ok: false, error: `HTTP ${r.status}` })))
      .then(data => this.responder(data))
      .catch(erro => this.mostrar(erro.message, false))
  }

  responder(data) {
    if (data.ok) return Turbo.visit(window.location.href, { action: "replace" })
    if (data.contar) return this.pedirContagem(data.contar, data.linhas)
    if (data.aviso) return this.mostrar(data.aviso, true)
    this.mostrar(data.error || "Não foi possível registrar a baixa", false)
  }

  // One row per line: its count and what to redo (Corte only if it cuts).
  pedirContagem(texto, linhas) {
    this.contagemTarget.replaceChildren(...linhas.map((linha, i) => this.linhaDaContagem(linha, i)))
    this.contagemTarget.hidden = false
    this.mostrar(texto, true)
    this.confirmarTarget.textContent = "Confirmar contagem"
  }

  linhaDaContagem(linha, i) {
    const linhaEl = document.createElement("div")
    linhaEl.className = "baixa-contagem-linha"
    const rotulo = document.createElement("label")
    const campo = document.createElement("input")
    Object.assign(campo, { type: "number", min: 0, step: 1, value: linha.contada, id: `${this.medidaTarget.id}-contagem-${i}` })
    campo.dataset.chave = linha.chave
    campo.className = "baixa-medida"
    rotulo.htmlFor = campo.id
    rotulo.textContent = `${linha.rotulo} (esperado ${linha.esperado})`
    const refazer = document.createElement("span")
    refazer.className = "baixa-contagem-refazer"
    refazer.append("refazer:", ...this.caixas(linha))
    linhaEl.append(rotulo, campo, refazer)
    return linhaEl
  }

  caixas(linha) {
    return [["impressao", "Impressão"], ...(linha.corta ? [["corte", "Corte"]] : [])].map(([valor, nome]) => {
      const caixa = Object.assign(document.createElement("input"), { type: "checkbox", value: valor, checked: true })
      caixa.dataset.refazer = ""
      caixa.dataset.linha = linha.chave
      const label = document.createElement("label")
      label.append(caixa, ` ${nome}`)
      return label
    })
  }

  mostrar(texto, podeConfirmar) {
    this.mensagemTarget.textContent = texto
    this.mensagemTarget.hidden = false
    this.mensagemTarget.classList.toggle("baixa-aviso", podeConfirmar)
    this.confirmarTarget.hidden = !podeConfirmar
  }

  limpar() {
    this.mensagemTarget.hidden = true
    this.confirmarTarget.hidden = true
    this.confirmarTarget.textContent = "Confirmar assim mesmo"
    this.contagemTarget.replaceChildren()
    this.contagemTarget.hidden = true
  }
}
