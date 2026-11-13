// The material missing, launched with a baixa or a delivery (decided
// 05/11/2026; pedidos/_dialogo_da_falta): one row per material × owner,
// starting at the minimum that frees the pedido, and — from who may not edit
// the stock — the email and password of someone who may. Plain module: the
// baixa and entrega controllers own the sending.
// Usage: const dialogo = new DialogoDaFalta(this.faltaTarget)
//        dialogo.abrir(data.faltas, data.pode_lancar); body fields: dialogo.campos()
export default class DialogoDaFalta {
  constructor(dialog) {
    this.dialog = dialog
    this.linhas = dialog.querySelector("[data-falta-linhas]")
    this.autorizador = dialog.querySelector("[data-falta-autorizador]")
    this.email = dialog.querySelector("[data-falta-email]")
    this.senha = dialog.querySelector("[data-falta-senha]")
    this.erro = dialog.querySelector("[data-falta-erro]")
  }

  get aberto() {
    return this.dialog.open
  }

  abrir(faltas, podeLancar) {
    this.linhas.replaceChildren(...faltas.map((falta, i) => this.linha(falta, i)))
    this.autorizador.hidden = podeLancar
    this.erro.hidden = true
    if (!this.dialog.open) this.dialog.showModal()
    this.linhas.querySelector("input")?.focus()
  }

  linha(falta, i) {
    const linhaEl = document.createElement("div")
    linhaEl.className = "baixa-falta-linha"
    const campo = Object.assign(document.createElement("input"), {
      type: "text", inputMode: "decimal", className: "baixa-medida", id: `${this.dialog.getAttribute("aria-labelledby")}-${i}`, value: metrosBr(falta.minimo)
    })
    campo.dataset.chave = falta.chave
    const rotulo = Object.assign(document.createElement("label"), { htmlFor: campo.id, textContent: `${falta.material} · ${falta.dono}` })
    const detalhe = document.createElement("span")
    detalhe.className = "baixa-esperado"
    // Dublagem 5b2a: the material's unit, m or kg.
    const u = falta.unidade || "m"
    detalhe.textContent = falta.minimo > falta.falta
      ? `faltam ${metrosBr(falta.falta)} ${u} deste pedido e ${metrosBr(falta.minimo - falta.falta)} ${u} de saídas anteriores — mínimo ${metrosBr(falta.minimo)} ${u}`
      : `faltam ${metrosBr(falta.falta)} ${u} — lance mais se chegou mais`
    linhaEl.append(rotulo, campo, ` ${u}`, detalhe)
    return linhaEl
  }

  // [name, value] pairs for the FormData.
  campos() {
    const campos = [...this.linhas.querySelectorAll("input[data-chave]")].map(input => [`entradas[${input.dataset.chave}]`, input.value])
    if (!this.autorizador.hidden) campos.push(["autorizador[email]", this.email.value], ["autorizador[senha]", this.senha.value])
    return campos
  }

  mostrarErro(texto) {
    this.erro.textContent = texto
    this.erro.hidden = false
  }

  fechar() {
    this.senha.value = ""
    this.dialog.close()
  }
}

function metrosBr(valor) {
  return (Math.round(valor * 100) / 100).toString().replace(".", ",")
}
