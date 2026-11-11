import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The queue changed (CanaisAoVivo.avisar_fila, Painel 2/4b): nothing else
// comes; the page refreshes itself.
Turbo.StreamActions.painel_fila = function () {
  document.dispatchEvent(new CustomEvent("painel:fila"))
}

// At most one refresh every few seconds (Q5a): a pedido's baixas come in a row.
const INTERVALO_MS = 3000

// How long "#… entregue" stays where its row was (Q3a).
const AVISO_DE_ENTREGA_MS = 6000

// The Painel (Painel 1/4, decided 04/11/2026): opening a pedido outlines its
// path and shows its faixa (Q3a), its items load when asked (Q2a), the filters
// hide rows, the counters count what is on the page. A reposição is a pedido
// inside its original's (decided 05/11/2026): filters and counters see the
// pair as one. Painel 2/4b: a sector's tab shows its numbered queue instead
// of the grid (Entrega still filters the grid); the page morph-refreshes
// when the queue changes and when a turno starts or ends, and puts back the
// tab, the filters, the counter and what was open (Q5a). Painel 2/4c: the
// Linha do tempo, switched in the page (the address keeps it); its window
// and order load in a frame, the filters, the sector and the counters
// apply to its bars too, a sector keeps only its load (Q7a). Painel 3/4a:
// ↑ ↓ in a sector's queue load the impact window into its dialog; once a
// move is saved the dialog closes and the page refreshes. Painel 3/4b: a
// pedido in the virada's warning opens in the grid, under Todos. Entregar
// pelo Painel (08/11/2026, Q3a): delivered, the page refreshes now and a
// short warning takes the place of the row (and of its bar) that left.
export default class extends Controller {
  static targets = ["quadro", "grade", "bloco", "contagem", "tipo", "cliente", "pendencia", "etapas", "tempo", "gradeTempo", "ordem", "comVisao", "impacto", "posicao"]
  static values = { itensUrl: String, colunas: Array, virada: Number, visao: String }

  connect() {
    this.filtroDoContador = ""
    this.setorAtual = ""
    this.aberto = null
    this.abertoNoTempo = null
    this.itensAbertos = new Set()
    this.ultimaRecarga = 0
    this.boundRecarga = () => this.pedirRecarga()
    this.boundRestaurar = () => this.restaurar()
    this.boundNovaJanela = (event) => this.novaJanela(event)
    this.boundFundoDoImpacto = (event) => { if (event.target === this.impactoTarget) this.fecharImpacto() }
    document.addEventListener("painel:fila", this.boundRecarga)
    document.addEventListener("turbo:morph", this.boundRestaurar)
    this.element.addEventListener("turbo:frame-load", this.boundNovaJanela)
    if (this.hasImpactoTarget) this.impactoTarget.addEventListener("click", this.boundFundoDoImpacto)
    this.aplicar()
  }

  disconnect() {
    document.removeEventListener("painel:fila", this.boundRecarga)
    document.removeEventListener("turbo:morph", this.boundRestaurar)
    this.element.removeEventListener("turbo:frame-load", this.boundNovaJanela)
    if (this.hasImpactoTarget) this.impactoTarget.removeEventListener("click", this.boundFundoDoImpacto)
    clearTimeout(this.recarga)
    // Stimulus reconnects this same instance when the element comes back: a
    // mark left set made pedirRecarga ignore every later "painel:fila" — the
    // Painel stopped refreshing by itself (producao-baixas, #197).
    this.recarga = null
    clearTimeout(this.timerDaVirada)
    clearTimeout(this.timerDoAviso)
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
    this.mostrarVisao()
    const aberto = this.aberto && document.getElementById(this.aberto)
    if (aberto) this.marcarAberto(aberto)
    this.reabrirNoTempo()
    this.itensAbertos.forEach((uuid) => this.carregarItens(document.getElementById(`painel_${uuid}`)))
    this.avisarEntregue()
  }

  // "entrega:feita" from the faixa or a cell (entrega_controller): where its
  // row and its bar were, then a refresh now — the broadcast's may be 3 s off.
  entregue(event) {
    const uuid = event.detail.pedido
    const lugares = [ `painel_${uuid}`, `tempo_${uuid}` ].map((id) => document.getElementById(id)).filter(Boolean)
      .map((elemento) => ({ id: elemento.id, antesDe: elemento.nextElementSibling?.id, em: elemento.parentElement }))
    this.entregaRecente = { uuid, lugares, ate: Date.now() + AVISO_DE_ENTREGA_MS }
    // Another pedido opened stays open; its own faixa leaves with its row.
    if ([ this.aberto, this.abertoNoTempo ].some((id) => lugares.some((lugar) => lugar.id === id))) this.fecharTodos()
    clearTimeout(this.recarga)
    this.recarga = null
    this.ultimaRecarga = 0
    this.pedirRecarga()
  }

  // Each morph drops what the server didn't send: put the warning back
  // until it expires. Still listed (Mostrar entregues): it moved, no warning.
  avisarEntregue() {
    const entrega = this.entregaRecente
    if (!entrega) return
    if (Date.now() > entrega.ate) return (this.entregaRecente = null)
    entrega.lugares.forEach((lugar) => {
      if (document.getElementById(lugar.id) || document.getElementById(`entregue_${lugar.id}`)) return
      const antes = lugar.antesDe && document.getElementById(lugar.antesDe)
      const pai = antes ? antes.parentElement : (lugar.em.isConnected ? lugar.em : this.quadroTarget)
      pai.insertBefore(this.avisoDeEntrega(entrega.uuid, lugar.id), antes || null)
    })
    clearTimeout(this.timerDoAviso)
    this.timerDoAviso = setTimeout(() => this.tirarAvisoDeEntrega(), entrega.ate - Date.now())
  }

  avisoDeEntrega(uuid, lugar) {
    const aviso = document.createElement("p")
    aviso.className = "painel-entregue-aviso"
    aviso.id = `entregue_${lugar}`
    aviso.setAttribute("role", "status")
    aviso.dataset.entregue = uuid
    const url = new URL(window.location.href)
    url.searchParams.set("entregues", "1")
    const link = document.createElement("a")
    link.href = url.pathname + url.search
    link.textContent = "ver em Entregues"
    aviso.append(`#${uuid.slice(0, 8)} entregue · `, link)
    return aviso
  }

  tirarAvisoDeEntrega() {
    this.entregaRecente = null
    this.element.querySelectorAll(".painel-entregue-aviso").forEach((aviso) => aviso.remove())
  }

  // ‹ › or the order brought another window: filter it, reopen its bar.
  // The impact frame loaded instead: show it, or close it once saved.
  novaJanela(event) {
    if (event?.target.id === "painel_impacto") return this.mostrarImpacto(event.target)
    this.aplicar()
    this.reabrirNoTempo()
  }

  mostrarImpacto(frame) {
    if (frame.querySelector("[data-impacto-feito]")) {
      this.fecharImpacto()
      this.ultimaRecarga = 0
      this.pedirRecarga()
      return
    }
    if (!this.impactoTarget.open) this.impactoTarget.showModal()
  }

  fecharImpacto() {
    if (this.impactoTarget.open) this.impactoTarget.close()
    this.impactoTarget.querySelector("turbo-frame").innerHTML = ""
  }

  // Another place picked: the window again with that move.
  outraPosicao() {
    this.posicaoTarget.requestSubmit()
  }

  trocarVisao(event) {
    this.irParaVisao(event.currentTarget.dataset.visao)
  }

  abrirDoAviso(event) {
    const pedido = document.getElementById(`painel_${event.currentTarget.dataset.pedido}`)
    if (!pedido) return
    this.setorAtual = ""
    this.filtroDoContador = ""
    this.marcarContador()
    this.irParaVisao("etapas")
    this.fecharTodos()
    this.marcarAberto(pedido)
    pedido.scrollIntoView({ block: "center" })
  }

  irParaVisao(visao) {
    this.visaoValue = visao
    const url = new URL(window.location.href)
    this.comVisao(url)
    window.history.replaceState(window.history.state, "", url)
    this.comVisaoTargets.forEach((link) => {
      const destino = new URL(link.href)
      this.comVisao(destino)
      link.href = destino.pathname + destino.search
    })
    this.mostrarVisao()
  }

  comVisao(url) {
    if (this.visaoValue === "tempo") url.searchParams.set("visao", "tempo")
    else url.searchParams.delete("visao")
  }

  mostrarVisao() {
    const tempo = this.visaoValue === "tempo"
    this.element.querySelectorAll(".painel-visao").forEach((botao) => botao.setAttribute("aria-pressed", String(botao.dataset.visao === this.visaoValue)))
    if (this.hasEtapasTarget) this.etapasTarget.hidden = tempo
    if (this.hasTempoTarget) this.tempoTarget.hidden = !tempo
    this.mostrarSetor()
  }

  ordenar() {
    this.ordemTarget.requestSubmit()
  }

  abrirNoTempo(event) {
    const pedido = event.currentTarget.closest(".painel-tempo-pedido")
    const jaAberto = pedido.classList.contains("painel-pedido--aberto")
    this.fecharTodos()
    if (!jaAberto) this.marcarAbertoNoTempo(pedido)
  }

  marcarAbertoNoTempo(pedido) {
    this.abertoNoTempo = pedido.id
    pedido.classList.add("painel-pedido--aberto")
    pedido.querySelector(".painel-faixa").hidden = false
    pedido.querySelector(".painel-ped-btn").setAttribute("aria-expanded", "true")
    this.gradeTempoTarget.classList.add("painel-tempo-grade--destaque")
  }

  reabrirNoTempo() {
    const aberto = this.abertoNoTempo && document.getElementById(this.abertoNoTempo)
    if (aberto && !aberto.hidden) this.marcarAbertoNoTempo(aberto)
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

  // Painel 3/4b3 (Q9a, the form of Q16a): "quem cruzou" — the lanes of the
  // pedidos that crossed it in the faixa's timeline, and their rows marked
  // in both views; again hides them.
  mostrarCruzou(event) {
    const botao = event.currentTarget
    const mostrar = botao.getAttribute("aria-expanded") !== "true"
    this.desmarcarCruzou()
    botao.closest(".painel-tdp").querySelectorAll("[data-tdp-cruzada]").forEach((item) => { item.hidden = !mostrar })
    botao.setAttribute("aria-expanded", String(mostrar))
    botao.textContent = botao.textContent.replace(mostrar ? "mostrar" : "esconder", mostrar ? "esconder" : "mostrar")
    if (!mostrar) return
    botao.dataset.cruzou.split(" ").forEach((uuid) => {
      this.element.querySelectorAll(`[data-uuid="${uuid}"]`).forEach((pedido) => pedido.classList.add("painel-cruzou"))
    })
  }

  desmarcarCruzou() {
    this.element.querySelectorAll(".painel-cruzou").forEach((pedido) => pedido.classList.remove("painel-cruzou"))
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
      // The Dublagem's tab lights both its columns (5b1c2).
      coluna.classList.toggle("painel-coluna--ativa", coluna.dataset.setor === this.setorAtual)
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
    this.aplicarNoTempo()
    // The opened pedido filtered out: nothing would be left undimmed.
    if (this.element.querySelector(".painel-pedido--aberto:is([hidden], .painel-pedido[hidden] *)")) this.fecharTodos()
    this.contar()
  }

  // A sector keeps the bars that go through it and only its load (Q7a).
  aplicarNoTempo() {
    const setor = this.setorAtual
    this.element.querySelectorAll(".painel-tempo-pedido").forEach((pedido) => {
      pedido.hidden = !(this.passa(pedido, { ignorarSetor: true }) && (!setor || this.naFila(pedido, setor)))
    })
    const cargas = this.element.querySelectorAll("[data-tempo-carga]")
    cargas.forEach((carga) => { carga.hidden = Boolean(setor) && carga.dataset.tempoCarga !== setor })
    const secao = this.element.querySelector("[data-tempo-cargas]")
    if (secao) secao.hidden = Array.from(cargas).every((carga) => carga.hidden)
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
    this.desmarcarCruzou()
    this.element.querySelectorAll(".painel-cruzou-btn[aria-expanded=true]").forEach((botao) => {
      botao.setAttribute("aria-expanded", "false")
      botao.textContent = botao.textContent.replace("esconder", "mostrar")
      botao.closest(".painel-tdp").querySelectorAll("[data-tdp-cruzada]").forEach((item) => { item.hidden = true })
    })
    this.aberto = null
    this.abertoNoTempo = null
    this.element.querySelectorAll(".painel-pedido, .painel-tempo-pedido").forEach((pedido) => {
      pedido.classList.remove("painel-pedido--aberto", "painel-pedido--contem")
      // A delivered bar has no faixa: it links to its resumo.
      if (!pedido.querySelector(".painel-faixa")) return
      pedido.querySelector(".painel-faixa").hidden = true
      pedido.querySelector(".painel-ped-btn").setAttribute("aria-expanded", "false")
    })
    this.gradeTarget.classList.remove("painel-grade--destaque")
    if (this.hasGradeTempoTarget) this.gradeTempoTarget.classList.remove("painel-tempo-grade--destaque")
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
