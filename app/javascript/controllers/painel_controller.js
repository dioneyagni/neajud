import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The queue changed (CanaisAoVivo.avisar_fila, Painel 2/4b): nothing else
// comes; the page refreshes itself.
Turbo.StreamActions.painel_fila = function () {
  document.dispatchEvent(new CustomEvent("painel:fila"))
}

// At most one refresh every few seconds (Q5a): a pedido's baixas come in a row.
const INTERVALO_MS = 3000

// The Painel (Painel 1/4, decided 04/11/2026): opening a pedido outlines its
// path and shows its faixa (Q3a), its items load when asked (Q2a), the filters
// hide rows, the counters count what is on the page. A reposição is a pedido
// inside its original's (decided 05/11/2026): filters and counters see the
// pair as one. Painel 2/4b: a sector's tab shows its numbered queue instead
// of the grid (Entrega still filters the grid); the page morph-refreshes
// when the queue changes and when a turno starts or ends, and puts back the
// tab, the filters, the counter and what was open (Q5a).
export default class extends Controller {
  static targets = ["quadro", "grade", "bloco", "contagem", "tipo", "cliente", "pendencia"]
  static values = { itensUrl: String, colunas: Array, virada: Number }

  connect() {
    this.filtroDoContador = ""
    this.setorAtual = ""
    this.aberto = null
    this.itensAbertos = new Set()
    this.ultimaRecarga = 0
    this.boundRecarga = () => this.pedirRecarga()
    this.boundRestaurar = () => this.restaurar()
    document.addEventListener("painel:fila", this.boundRecarga)
    document.addEventListener("turbo:morph", this.boundRestaurar)
    this.aplicar()
  }

  disconnect() {
    document.removeEventListener("painel:fila", this.boundRecarga)
    document.removeEventListener("turbo:morph", this.boundRestaurar)
    clearTimeout(this.recarga)
    clearTimeout(this.timerDaVirada)
  }

  // The next turno to start or end refreshes the blocks ("Agora") by itself.
  viradaValueChanged() {
    clearTimeout(this.timerDaVirada)
    if (!this.viradaValue) return
    const espera = this.viradaValue - Date.now() + 1000
    if (espera > 0 && espera < 2 ** 31) this.timerDaVirada = setTimeout(() => this.pedirRecarga(), espera)
  }

  pedirRecarga() {
    if (this.recarga) return
    const espera = Math.max(0, this.ultimaRecarga + INTERVALO_MS - Date.now())
    this.recarga = setTimeout(() => {
      this.recarga = null
      this.ultimaRecarga = Date.now()
      Turbo.session.refresh(document.baseURI)
    }, espera)
  }

  // After the morph the server's HTML is back: hidden rows, tabs, selects.
  restaurar() {
    this.tipoTarget.value = this.filtros?.tipo ?? ""
    this.clienteTarget.value = this.filtros?.cliente ?? ""
    this.pendenciaTarget.checked = this.filtros?.pendencia ?? false
    this.marcarContador()
    this.mostrarSetor()
    const aberto = this.aberto && document.getElementById(this.aberto)
    if (aberto) this.marcarAberto(aberto)
    this.itensAbertos.forEach((uuid) => this.carregarItens(document.getElementById(`painel_${uuid}`)))
  }

  abrir(event) {
    const pedido = event.currentTarget.closest(".painel-pedido")
    const jaAberto = pedido.classList.contains("painel-pedido--aberto")
    this.fecharTodos()
    if (!jaAberto) this.marcarAberto(pedido)
  }

  itens(event) {
    const pedido = event.currentTarget.closest(".painel-pedido")
    const caixa = pedido.querySelector("[data-painel-itens]")
    if (!caixa.hidden) {
      caixa.hidden = true
      event.currentTarget.setAttribute("aria-expanded", "false")
      this.itensAbertos.delete(pedido.dataset.uuid)
      return
    }
    this.itensAbertos.add(pedido.dataset.uuid)
    this.carregarItens(pedido)
  }

  async carregarItens(pedido) {
    if (!pedido) return
    const resposta = await fetch(this.urlCom(this.itensUrlValue, pedido.dataset.uuid), { headers: { Accept: "text/html" } })
    if (!resposta.ok) return
    const caixa = pedido.querySelector("[data-painel-itens]")
    caixa.innerHTML = await resposta.text()
    caixa.hidden = false
    pedido.querySelector(".painel-itens-btn")?.setAttribute("aria-expanded", "true")
  }

  setor(event) {
    this.setorAtual = event.currentTarget.dataset.setor
    this.mostrarSetor()
  }

  // A production sector shows its queue; Todos and Entrega the grid.
  mostrarSetor() {
    this.element.querySelectorAll(".painel-setor").forEach((botao) => {
      const ativo = botao.dataset.setor === this.setorAtual
      botao.classList.toggle("painel-setor--ativo", ativo)
      botao.setAttribute("aria-pressed", String(ativo))
    })
    const fila = this.filaDoSetor(this.setorAtual)
    this.element.querySelectorAll("[data-fila-setor]").forEach((secao) => { secao.hidden = secao !== fila })
    this.quadroTarget.hidden = Boolean(fila)
    this.gradeTarget.dataset.setor = this.setorAtual
    this.gradeTarget.querySelectorAll(".painel-cab [data-coluna]").forEach((coluna) => {
      coluna.classList.toggle("painel-coluna--ativa", coluna.dataset.coluna === this.setorAtual)
    })
    this.aplicar()
  }

  contador(event) {
    const filtro = event.currentTarget.dataset.filtro
    this.filtroDoContador = this.filtroDoContador === filtro ? "" : filtro
    this.marcarContador()
    this.aplicar()
  }

  marcarContador() {
    this.element.querySelectorAll(".painel-cont").forEach((botao) => {
      botao.classList.toggle("painel-cont--ativo", botao.dataset.filtro === this.filtroDoContador)
    })
  }

  filtrar() {
    this.filtros = { tipo: this.tipoTarget.value, cliente: this.clienteTarget.value, pendencia: this.pendenciaTarget.checked }
    this.aplicar()
  }

  // Hides what the filters leave out, then counts what is left.
  aplicar() {
    this.pedidos().forEach((pedido) => { pedido.hidden = !this.passa(pedido) })
    this.element.querySelectorAll("[data-fila-pedido]").forEach((linha) => { linha.hidden = !this.passaNosFiltros(linha) })
    // The opened pedido filtered out: nothing would be left undimmed.
    if (this.element.querySelector(".painel-pedido--aberto:is([hidden], [hidden] *)")) this.fecharTodos()
    this.contar()
  }

  passa(pedido, { ignorarSetor = false } = {}) {
    if (!this.passaNosFiltros(pedido)) return false
    if (!ignorarSetor && this.setorAtual && !this.filaDoSetor(this.setorAtual) && !this.naFila(pedido, this.setorAtual)) return false
    return this.passaNoContador(pedido)
  }

  passaNosFiltros(elemento) {
    const d = elemento.dataset
    if (this.tipoTarget.value && d.tipo !== this.tipoTarget.value) return false
    if (this.clienteTarget.value && d.cliente !== this.clienteTarget.value) return false
    return !(this.pendenciaTarget.checked && d.pendencia !== "true")
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

  filaDoSetor(setor) {
    return setor ? this.element.querySelector(`[data-fila-setor="${setor}"]`) : null
  }

  contar() {
    const todos = this.pedidos()
    this.contagemTargets.forEach((alvo) => {
      const conta = alvo.dataset.conta
      if (conta.startsWith("fila:")) {
        alvo.textContent = this.naFilaDoSetor(conta.slice(5), todos)
      } else if (conta.startsWith("bloco:")) {
        alvo.textContent = todos.filter((p) => p.dataset.bloco === conta.slice(6)).length
      } else {
        alvo.textContent = todos.filter((p) => p.dataset[conta] === "true").length
      }
    })
  }

  // A queue counts its pedidos once, even split over turnos.
  naFilaDoSetor(setor, todos) {
    const fila = this.filaDoSetor(setor)
    if (!fila) return todos.filter((p) => this.naFila(p, setor) && this.passa(p, { ignorarSetor: true })).length
    const linhas = Array.from(fila.querySelectorAll("[data-fila-pedido]")).filter((linha) => this.passaNosFiltros(linha))
    return new Set(linhas.map((linha) => linha.dataset.filaPedido)).size
  }

  marcarAberto(pedido) {
    this.aberto = pedido.id
    pedido.classList.add("painel-pedido--aberto")
    // An opened reposição: its original stays lit around it.
    pedido.parentElement.closest(".painel-pedido")?.classList.add("painel-pedido--contem")
    pedido.querySelector(".painel-faixa").hidden = false
    pedido.querySelector(".painel-ped-btn").setAttribute("aria-expanded", "true")
    this.gradeTarget.classList.add("painel-grade--destaque")
  }

  fecharTodos() {
    this.aberto = null
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
