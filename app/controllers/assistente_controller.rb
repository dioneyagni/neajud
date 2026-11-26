# The first-run wizard (Primeiros passos 2/6a, decided 20/11/2026, canvas
# "Primeiros passos", 7–11): right after the first access (Q2a), the dono
# answers a step at a time; each step is saved as it is answered
# (AplicarPassoDoAssistente), so "Fazer depois" or closing the page resumes
# where it stopped. The steps are PassosDoAssistente's list. Redoing it from
# Parâmetros › Empresa shows what exists as done and only adds.
class AssistenteController < ApplicationController
  exige_dono
  layout "assistente"

  rescue_from PassosDoAssistente::Desconhecido do
    head :not_found
  end

  # Usage: GET /assistente — the step it stopped at, else the first.
  def show
    redirect_to passo_do_assistente_path(empresa.assistente_passo.presence || PassosDoAssistente.primeiro.chave)
  end

  # Usage: GET /assistente/horario — only shows: where it stopped is saved
  # by answering a step or by "Fazer depois".
  def passo
    @passo = PassosDoAssistente.passo(params[:passo])
    preparar
  end

  # Usage: PATCH /assistente/horario (the step's fields)
  def salvar
    @passo = PassosDoAssistente.passo(params[:passo])
    resultado = AplicarPassoDoAssistente.call(@passo.chave, dados_do_passo, empresa: empresa, autoria: autoria)
    return recusar(resultado) unless resultado.ok?

    flash[:alert] = resultado.avisos.to_sentence if resultado.avisos.any?
    seguinte = PassosDoAssistente.seguinte(@passo.chave)
    return concluir unless seguinte

    empresa.update!(assistente_passo: seguinte.chave)
    redirect_to passo_do_assistente_path(seguinte.chave)
  end

  # "Fazer depois" (Q2a): everything stays on, as before the wizard; the
  # Painel reminds the dono until it ends, from the step he left.
  # Usage: POST /assistente/depois (passo=horario)
  def depois
    passo = PassosDoAssistente.passo(params[:passo].presence || PassosDoAssistente.primeiro.chave)
    visiveis(Empresa).first!.update!(assistente_passo: passo.chave) unless visiveis(Empresa).first!.assistente_concluido_em
    redirect_to painel_path, notice: "Tudo bem: o assistente continua de onde você parou, pelo aviso no Painel."
  end

  private

  def empresa
    @empresa ||= visiveis(Empresa).first!
  end

  def dados_do_passo
    params.fetch(:assistente, {}).permit(:tecido_de, :clientes_entram, :feriados, tipos: [], funcoes: [], materiais: [],
                                         turnos: [ :nome, :inicio, :fim, { dias: [] } ], maquinas: %i[nome trabalho por_hora]).to_h
  end

  def recusar(resultado)
    @erros = resultado.erros
    preparar
    render :passo, status: :unprocessable_content
  end

  def concluir
    empresa.update!(assistente_passo: nil, assistente_concluido_em: Time.current)
    redirect_to painel_path, notice: "Pronto! A fábrica está configurada. Dá para refazer o assistente em Parâmetros › Empresa."
  end

  # What each step shows: the kinds marked, and what already exists (done).
  def preparar
    @tipos = empresa.tipos_produzidos
    @funcoes = visiveis(Funcao).where(nome: ConteudoDoAssistente.funcoes.keys + [ "Cliente final" ]).index_by(&:nome)
    @turnos = visiveis(Turno).ativos.order(:inicio_min).to_a
    @maquinas = visiveis(Maquina).ativos.includes(:trabalhos).order(:nome).to_a
    @materiais = ConteudoDoAssistente.materiais_de(@tipos || ConteudoDoAssistente.tipos.keys)
    @existentes = @materiais.transform_values { |dados| CadastroDeMateriais.existente(dados) }.compact
    visiveis(MateriaPrima)
  end
end
