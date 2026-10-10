# The Usuários page (Etapa 0.5, 3/4): whoever may "gerenciar usuários" adds
# people with a função, extra accesses and a provisional password, resets
# passwords and deactivates/reactivates. GestaoDeUsuarios holds the rules
# (donos, not giving more than you have, always one active dono).
# A cliente final's access (Etapa 2.8, 2/5) is created and listed on its
# client's page, with these same actions; it comes back there after each.
class UsuariosController < ApplicationController
  exige_acao :gerenciar_usuarios
  before_action :set_usuario, only: %i[edit update redefinir_senha desativar reativar]
  before_action :exigir_gestao_do_usuario, only: %i[edit update redefinir_senha desativar reativar]

  def index
    @usuarios = visiveis(User).da_equipe.includes(vinculos: :funcao).order(Arel.sql("desativado_em IS NOT NULL"), :nome)
  end

  def new
    @usuario = visiveis(User).new
  end

  def create
    cliente = visiveis(Client).ativos.por_uuid!(usuario_params[:client_uuid]) if usuario_params[:client_uuid].present?
    @usuario = CadastroDeUsuarioService.call(gestor: Current.user, user: visiveis(User).new, dados: usuario_params, cliente: cliente)
    return recusar_acesso_do_cliente(cliente) if cliente && @usuario.errors.any?
    return render :new, status: :unprocessable_content if @usuario.errors.any?

    redirect_to destino(@usuario), notice: "#{@usuario.nome} added. Give them the provisional password; they will change it at the first sign-in."
  end

  def edit
  end

  def update
    @usuario = CadastroDeUsuarioService.call(gestor: Current.user, user: @usuario, dados: usuario_params)
    return render :edit, status: :unprocessable_content if @usuario.errors.any?

    redirect_to destino(@usuario), notice: "#{@usuario.nome} updated."
  end

  def redefinir_senha
    @usuario.definir_senha_provisoria!(params.require(:senha_provisoria))
    redirect_to destino(@usuario), notice: "New provisional password set for #{@usuario.nome}; they must change it at the next sign-in."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_usuario_path(@usuario), alert: e.record.errors.full_messages.to_sentence
  end

  def desativar
    erros = GestaoDeUsuarios.new(Current.user).erros_para_desativar(@usuario)
    return redirect_to destino(@usuario), alert: erros.to_sentence if erros.any?

    @usuario.desativar!(por: Current.user)
    redirect_to destino(@usuario), notice: "#{@usuario.nome} deactivated: can't sign in any more."
  end

  def reativar
    @usuario.reativar!
    redirect_to destino(@usuario), notice: "#{@usuario.nome} reactivated."
  end

  private

  def set_usuario
    @usuario = visiveis(User).find_by!(uuid: params[:uuid])
  end

  def exigir_gestao_do_usuario
    exigir!(GestaoDeUsuarios.new(Current.user).pode_gerir?(@usuario), "dono (to manage a dono)")
  end

  # A cliente final's access lives on its client's page.
  def destino(usuario)
    cliente = usuario.cliente
    cliente ? client_path(cliente, anchor: "acesso-ao-sistema") : usuarios_path
  end

  # The client's page has the form; it shows what was refused.
  def recusar_acesso_do_cliente(cliente)
    redirect_to client_path(cliente, anchor: "acesso-ao-sistema"), alert: @usuario.errors.full_messages.to_sentence
  end

  def usuario_params
    params.expect(usuario: [ :nome, :email_address, :funcao_uuid, :senha_provisoria, :client_uuid,
                             { acessos_extras: { niveis: Autorizacao::AREAS, acoes: [] } } ]).to_h
  end
end
