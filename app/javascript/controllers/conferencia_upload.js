// The upload's conference (Etapa 1.2, 2/3 parte 3): the groups the server
// proposed (POST /arquivos/agrupamento), edited before anything is sent —
// each file's part, size, side (DIR / ESQ, Etapa 1.2, 3/3 parte 3c) and
// piloto, separate a file, join two groups, or
// add a group to an existing arte (suggested, never chosen for the user).
// Plain module: upload_controller.js owns the files and the sending.
export default class ConferenciaDoUpload {
  // tipo: the kind chosen for the upload (Etapa 2.5a), each group's to start.
  constructor(resposta, escapar, tipo = "calcado") {
    this.pecas = resposta.pecas
    this.escapar = escapar
    this.tipos = resposta.tipos || []
    this.grupos = resposta.grupos.map((grupo, id) => ({ ...grupo, id, tipo, existente: null, arquivos: grupo.arquivos.map(a => ({ ...a })) }))
    this.proximoId = this.grupos.length
  }

  get totalDeArtes() {
    return this.grupos.length
  }

  // One handler for every control: data-acao names what changed.
  // Returns true when the list must be drawn again.
  aplicar(evento) {
    const alvo = evento.currentTarget
    const acao = { parte: "escolherParte", tamanho: "editarTamanho", lado: "escolherLado", piloto: "marcarPiloto", separar: "separar", juntar: "juntar", existente: "escolherExistente", tipo: "escolherTipo" }[alvo.dataset.acao]
    return acao ? this[acao](alvo) : false
  }

  escolherParte(alvo) {
    const arquivo = this.arquivo(alvo.dataset.indice)
    arquivo.parte_uuid = alvo.value || null
    if (arquivo.piloto) this.umPilotoPorParte(arquivo)
    return true
  }

  editarTamanho(alvo) {
    this.arquivo(alvo.dataset.indice).tamanho = alvo.value.trim() || null
    return false
  }

  escolherLado(alvo) {
    this.arquivo(alvo.dataset.indice).lado = alvo.value || null
    return false
  }

  marcarPiloto(alvo) {
    const arquivo = this.arquivo(alvo.dataset.indice)
    arquivo.piloto = alvo.checked
    if (arquivo.piloto) this.umPilotoPorParte(arquivo)
    return true
  }

  separar(alvo) {
    const arquivo = this.arquivo(alvo.dataset.indice)
    const grupo = this.grupoDe(arquivo)
    grupo.arquivos = grupo.arquivos.filter(a => a !== arquivo)
    this.grupos.push({ id: this.proximoId++, titulo: alvo.dataset.nome, tipo: grupo.tipo, existentes: [], existente: null, arquivos: [arquivo] })
    return true
  }

  juntar(alvo) {
    const origem = this.grupos.find(g => g.id === Number(alvo.dataset.grupo))
    const destino = this.grupos.find(g => g.id === Number(alvo.value))
    if (!origem || !destino) return false
    destino.arquivos.push(...origem.arquivos)
    this.grupos = this.grupos.filter(g => g !== origem)
    return true
  }

  escolherTipo(alvo) {
    this.grupos.find(g => g.id === Number(alvo.dataset.grupo)).tipo = alvo.value
    return false
  }

  // The upload's kind changed: every group takes it. Returns true to redraw.
  todosDoTipo(tipo) {
    this.grupos.forEach(g => { g.tipo = tipo })
    return true
  }

  escolherExistente(alvo) {
    this.grupos.find(g => g.id === Number(alvo.dataset.grupo)).existente = alvo.value || null
    return false
  }

  // [{ indice, campos }] in group order; criarArte() makes a group's arte.
  async plano(criarArte) {
    const plano = []
    for (const grupo of this.grupos) {
      const precisaDeArte = grupo.arquivos.length > 1 || grupo.arquivos.some(a => a.piloto)
      const arteUuid = grupo.existente || (precisaDeArte ? await criarArte(grupo.tipo) : null)
      for (const a of grupo.arquivos) {
        plano.push({ indice: a.indice, campos: { arte_uuid: arteUuid, tipo: grupo.tipo, peca_uuid: a.parte_uuid, tamanho_rotulo: a.tamanho, lado: a.lado, papel: a.piloto ? "piloto" : null } })
      }
    }
    return plano
  }

  html(arquivos) {
    return this.grupos.map(grupo => this.htmlDoGrupo(grupo, arquivos)).join("")
  }

  htmlDoGrupo(grupo, arquivos) {
    const outros = this.grupos.filter(g => g !== grupo).map(g => `<option value="${g.id}">${this.escapar(this.tituloDe(g, arquivos))}</option>`).join("")
    return `<div class="conferencia-grupo" data-grupo="${grupo.id}">
      <div class="conferencia-grupo-topo">
        <strong class="conferencia-grupo-titulo">${this.escapar(this.tituloDe(grupo, arquivos))}</strong>
        <span class="conferencia-grupo-contagem">${grupo.arquivos.length} file${grupo.arquivos.length > 1 ? "s" : ""}</span>
        ${this.htmlDoTipo(grupo)}
        ${outros ? `<select class="conferencia-juntar" data-acao="juntar" data-grupo="${grupo.id}" data-action="change->upload#conferir"><option value="">Join with…</option>${outros}</select>` : ""}
      </div>
      ${this.htmlDosExistentes(grupo)}
      ${grupo.arquivos.map(a => this.htmlDoArquivo(a, arquivos[a.indice], grupo)).join("")}
    </div>`
  }

  htmlDoTipo(grupo) {
    if (!this.tipos.length) return ""
    const opcoes = this.tipos.map(t => `<option value="${t.tipo}" ${t.tipo === grupo.tipo ? "selected" : ""}>${this.escapar(t.rotulo)}</option>`).join("")
    return `<select class="conferencia-tipo" title="Kind of work" data-acao="tipo" data-grupo="${grupo.id}" data-action="change->upload#conferir">${opcoes}</select>`
  }

  htmlDosExistentes(grupo) {
    if (!grupo.existentes.length) return ""
    const nome = `existente-${grupo.id}`
    const opcao = (valor, conteudo) => `<label class="conferencia-existente"><input type="radio" name="${nome}" value="${valor}" data-acao="existente" data-grupo="${grupo.id}" data-action="change->upload#conferir" ${(grupo.existente || "") === valor ? "checked" : ""}> ${conteudo}</label>`
    const existentes = grupo.existentes.map(e =>
      opcao(e.arte_uuid, `${e.preview ? `<img class="conferencia-existente-thumb" src="${e.preview}" alt="">` : ""}Add to <a href="${e.url}" target="_blank">${this.escapar(e.titulo)}</a> <span>${this.escapar(e.resumo)}</span>`))
    return `<div class="conferencia-existentes"><p>Looks like an arte already in the system:</p>${opcao("", "A new arte")}${existentes.join("")}</div>`
  }

  htmlDoArquivo(a, arquivo, grupo) {
    const opcoes = this.pecas.map(p => `<option value="${p.uuid}" ${p.uuid === a.parte_uuid ? "selected" : ""}>${this.escapar(p.nome)}</option>`).join("")
    return `<div class="upload-file conferencia-arquivo${a.piloto ? " conferencia-arquivo--piloto" : ""}" data-index="${a.indice}">
      <label class="conferencia-piloto" title="The editable master of its part"><input type="checkbox" data-acao="piloto" data-indice="${a.indice}" data-action="change->upload#conferir" ${a.piloto ? "checked" : ""}> ★ piloto</label>
      <span class="upload-file-name">${this.escapar(arquivo.name)}</span>
      <span class="upload-file-size">${(arquivo.size / 1048576).toFixed(1)} MB</span>
      <select class="conferencia-parte${a.parte_uuid ? "" : " conferencia-parte--vazia"}" data-acao="parte" data-indice="${a.indice}" data-action="change->upload#conferir"><option value="">Part…</option>${opcoes}</select>
      <input type="text" class="conferencia-tamanho" placeholder="Size" value="${this.escapar(a.tamanho || "")}" data-acao="tamanho" data-indice="${a.indice}" data-action="input->upload#conferir">
      <select class="conferencia-lado" title="Side of a mirrored part" data-acao="lado" data-indice="${a.indice}" data-action="change->upload#conferir">${[["", "Side…"], ["direito", "DIR"], ["esquerdo", "ESQ"]].map(([v, t]) => `<option value="${v}" ${(a.lado || "") === v ? "selected" : ""}>${t}</option>`).join("")}</select>
      <span class="upload-file-status"></span>
      ${grupo.arquivos.length > 1 ? `<button type="button" class="conferencia-separar" data-acao="separar" data-indice="${a.indice}" data-nome="${this.escapar(arquivo.name)}" data-action="click->upload#conferir">Separate</button>` : ""}
      <button type="button" class="upload-file-remove" data-action="click->upload#removeFile" data-index="${a.indice}">×</button>
    </div>`
  }

  tituloDe(grupo, arquivos) {
    return grupo.titulo || arquivos[grupo.arquivos[0].indice].name
  }

  umPilotoPorParte(piloto) {
    this.grupoDe(piloto).arquivos.forEach(a => { if (a !== piloto && a.parte_uuid === piloto.parte_uuid) a.piloto = false })
  }

  arquivo(indice) {
    return this.grupos.flatMap(g => g.arquivos).find(a => a.indice === Number(indice))
  }

  grupoDe(arquivo) {
    return this.grupos.find(g => g.arquivos.includes(arquivo))
  }
}
