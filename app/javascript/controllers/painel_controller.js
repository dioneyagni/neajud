import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The live update of the Painel (Painel 1/4): the server sends only which
// pedido changed (CanaisAoVivo.avisar_painel); the page asks for its row.
Turbo.StreamActions.painel_linha = function () {
  const uuid = this.target.replace(/^painel_/, "")
  document.dispatchEvent(new CustomEvent("painel:linha", { detail: { uuid } }))
}

// The Painel (Painel 1/4, decided 04/11/2026): opening a pedido outlines its
// path and shows its faixa (Q3a), its items load when asked (Q2a), the sector
// tabs and the filters hide rows, the counters count what is on the page.
// A row that changed comes back alone and keeps its place if opened. A
// reposição is a pedido inside its original's (decided 05/11/2026): filters
// and counters see the pair as one.
export default class extends Controller {
  static targets = ["grade", "bloco", "contagem", "tipo", "cliente", "pendencia"]
  static values = { linhaUrl: String, itensUrl: String, colunas: Array }

  connect() {
    this.filtroDoContador = ""
    this.setorAtual = ""
    this.boundAtualizar = (event) => this.atualizarLinha(event.detail.uuid)
    document.addEventListener("painel:linha", this.boundAtualizar)
    this.aplicar()
  }

  disconnect() {
    document.removeEventListener("painel:linha", this.boundAtualizar)
  }

  abrir(event) {
    const pedido = event.currentTarget.closest(".painel-pedido")
    const jaAberto = pedido.classList.contains("painel-pedido--aberto")
    this.fecharTodos()
    if (!jaAberto) this.marcarAberto(pedido)
  }

  async itens(event) {
    const botao = event.currentTarget
    const caixa = botao.closest(".painel-pedido").querySelector("[data-painel-itens]")
    const abrir = caixa.hidden
    botao.setAttribute("aria-expanded", String(abrir))
    if (!abrir) { caixa.hidden = true; return }

    const resposta = await fetch(this.urlCom(this.itensUrlValue, botao.closest(".painel-pedido").dataset.uuid), { headers: { Accept: "text/html" } })
    if (!resposta.ok) return
    caixa.innerHTML = await resposta.text()
    caixa.hidden = false
  }

  setor(event) {
    this.setorAtual = event.currentTarget.dataset.setor
    this.element.querySelectorAll(".painel-setor").forEach((botao) => {
      const ativo = botao.dataset.setor === this.setorAtual
      botao.classList.toggle("painel-setor--ativo", ativo)
      botao.setAttribute("aria-pressed", String(ativo))
    })
    this.gradeTarget.dataset.setor = this.setorAtual
    this.gradeTarget.querySelectorAll(".painel-cab [data-coluna]").forEach((coluna) => {
      coluna.classList.toggle("painel-coluna--ativa", coluna.dataset.coluna === this.setorAtual)
    })
    this.aplicar()
  }

  contador(event) {
    const filtro = event.currentTarget.dataset.filtro
    this.filtroDoContador = this.filtroDoContador === filtro ? "" : filtro
    this.element.querySelectorAll(".painel-cont").forEach((botao) => {
      botao.classList.toggle("painel-cont--ativo", botao.dataset.filtro === this.filtroDoContador)
    })
    this.aplicar()
  }

  filtrar() {
    this.aplicar()
  }

  // Hides what the filters leave out, then counts what is left.
  aplicar() {
    this.pedidos().forEach((pedido) => { pedido.hidden = !this.passa(pedido) })
    // The opened pedido filtered out: nothing would be left undimmed.
    if (this.element.querySelector(".painel-pedido--aberto:is([hidden], [hidden] *)")) this.fecharTodos()
    this.contar()
  }

  passa(pedido, { ignorarSetor = false } = {}) {
    const d = pedido.dataset
    if (this.tipoTarget.value && d.tipo !== this.tipoTarget.value) return false
    if (this.clienteTarget.value && d.cliente !== this.clienteTarget.value) return false
    if (this.pendenciaTarget.checked && d.pendencia !== "true") return false
    if (!ignorarSetor && this.setorAtual && !this.naFila(pedido, this.setorAtual)) return false
    return this.passaNoContador(pedido)
  }

  passaNoContador(pedido) {
    const filtro = this.filtroDoContador
    if (!filtro) return true
    if (filtro.startsWith("bloco:")) return pedido.dataset.bloco === filtro.slice(6)
    return pedido.dataset[filtro] === "true"
  }

  naFila(pedido, setor) {
    return pedido.dataset.filas.split(" ").includes(setor)
  }

  contar() {
    const todos = this.pedidos()
    this.contagemTargets.forEach((alvo) => {
      const conta = alvo.dataset.conta
      if (conta.startsWith("fila:")) {
        alvo.textContent = todos.filter((p) => this.naFila(p, conta.slice(5)) && this.passa(p, { ignorarSetor: true })).length
      } else if (conta.startsWith("bloco:")) {
        alvo.textContent = todos.filter((p) => p.dataset.bloco === conta.slice(6)).length
      } else {
        alvo.textContent = todos.filter((p) => p.dataset[conta] === "true").length
      }
    })
  }

  // A reposição under its original comes back as the original's row.
  async atualizarLinha(uuid) {
    const resposta = await fetch(this.urlCom(this.linhaUrlValue, uuid), { headers: { Accept: "text/html" } })
    const anterior = document.getElementById(`painel_${uuid}`)
    if (resposta.status === 204) { anterior?.remove(); this.aplicar(); return }
    if (!resposta.ok) return

    const modelo = document.createElement("template")
    modelo.innerHTML = (await resposta.text()).trim()
    const nova = modelo.content.firstElementChild
    // A column no row used before: the grid needs the whole page.
    if (nova.dataset.fora) { Turbo.visit(window.location.href, { action: "replace" }); return }

    const atual = document.getElementById(nova.id)
    // A reposição that was a row of its own now comes inside its original.
    if (anterior && anterior !== atual && !atual?.contains(anterior)) anterior.remove()
    const aberto = this.element.querySelector(".painel-pedido--aberto")?.id
    this.colocar(nova, atual)
    if (aberto && document.getElementById(aberto)) this.marcarAberto(document.getElementById(aberto))
    this.aplicar()
  }

  colocar(nova, atual) {
    const bloco = this.blocoTargets.find((alvo) => alvo.dataset.bloco === nova.dataset.bloco)
    if (!bloco) { atual?.remove(); return }
    if (atual && atual.parentElement === bloco) { atual.replaceWith(nova); return }

    atual?.remove()
    bloco.append(nova)
  }

  marcarAberto(pedido) {
    pedido.classList.add("painel-pedido--aberto")
    // An opened reposição: its original stays lit around it.
    pedido.parentElement.closest(".painel-pedido")?.classList.add("painel-pedido--contem")
    pedido.querySelector(".painel-faixa").hidden = false
    pedido.querySelector(".painel-ped-btn").setAttribute("aria-expanded", "true")
    this.gradeTarget.classList.add("painel-grade--destaque")
  }

  fecharTodos() {
    this.element.querySelectorAll(".painel-pedido").forEach((pedido) => {
      pedido.classList.remove("painel-pedido--aberto", "painel-pedido--contem")
      pedido.querySelector(".painel-faixa").hidden = true
      pedido.querySelector(".painel-ped-btn").setAttribute("aria-expanded", "false")
    })
    this.gradeTarget.classList.remove("painel-grade--destaque")
  }

  // The top rows: a reposição inside its original is not counted twice.
  pedidos() {
    return Array.from(this.element.querySelectorAll("[data-painel-target=bloco] > .painel-pedido"))
  }

  urlCom(modelo, uuid) {
    const url = new URL(modelo.replace("UUID", uuid), window.location.origin)
    this.colunasValue.forEach((coluna) => url.searchParams.append("colunas[]", coluna))
    return url
  }
}
