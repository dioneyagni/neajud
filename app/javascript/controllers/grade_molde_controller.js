import { Controller } from "@hotwired/stimulus"

// Fills a molde's first/last size from its modelo's product grade (Etapa 1.1,
// 3/5). Each modelo <option> carries data-grade (JSON list, empty for Banner).
// A value wanted before the options exist (the dialog's Edit prefill) waits in
// data-valor; a new molde starts with the whole grade.
export default class extends Controller {
  static targets = ["modelo", "inicial", "final"]

  connect() {
    this.atualizar()
  }

  atualizar() {
    const opcao = this.modeloTarget.selectedOptions[0]
    const grade = JSON.parse(opcao?.dataset.grade || "[]")
    this._preencher(this.inicialTarget, grade, grade[0])
    this._preencher(this.finalTarget, grade, grade[grade.length - 1])
  }

  _preencher(select, grade, padrao) {
    const desejado = select.dataset.valor || select.value
    delete select.dataset.valor
    select.innerHTML = '<option value="">—</option>' +
      grade.map((tamanho) => `<option value="${tamanho}">${tamanho}</option>`).join("")
    select.value = grade.includes(desejado) ? desejado : (padrao || "")
  }
}
