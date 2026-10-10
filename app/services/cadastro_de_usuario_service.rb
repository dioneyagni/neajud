# Creates or updates a user from the Usuários page (Etapa 0.5, 3/4): name,
# email, função and acessos extras, checked against GestaoDeUsuarios; a new
# user gets a provisional password to change at the first sign-in. Given a
# `cliente`, the new user is that client's cliente final (Etapa 2.8, 2/5:
# created on the client's page); an existing user keeps its client.
#
# Usage: user = CadastroDeUsuarioService.call(gestor: Current.user, user: User.new,
#          dados: { nome: "João", email_address: "joao@x.com", funcao_uuid: "…",
#                   acessos_extras: { "niveis" => { "pedidos" => "2" } }, senha_provisoria: "…" })
#        user.errors.empty? # => true when saved
#        CadastroDeUsuarioService.call(gestor: Current.user, user: User.new, dados: { … }, cliente: client)
class CadastroDeUsuarioService
  # Form values → stored shape: only levels above "—" and checked actions.
  # Usage: normalizar_extras({ "niveis" => { "pedidos" => "2", "artes" => "0" }, "acoes" => [ "" ] })
  #   # => { "niveis" => { "pedidos" => 2 }, "acoes" => [] }
  def self.normalizar_extras(extras)
    extras = extras.to_h.stringify_keys
    niveis = extras.fetch("niveis", {}).to_h.transform_values { |nivel| Integer(nivel, exception: false) || nivel }
    { "niveis" => niveis.reject { |_area, nivel| nivel == 0 }, "acoes" => Array(extras["acoes"]).compact_blank }
  end

  def self.call(gestor:, user:, dados:, cliente: nil)
    new(gestor, user, dados.to_h.symbolize_keys, cliente).call
  end

  def initialize(gestor, user, dados, cliente = nil)
    @gestao = GestaoDeUsuarios.new(gestor)
    @user = user
    @cliente = cliente
    @dados = dados
    @funcao = Funcao.ativos.find_by(uuid: dados[:funcao_uuid])
    @extras = self.class.normalizar_extras(dados[:acessos_extras])
  end

  def call
    preparar
    salvar if valido?
    @user
  end

  private

  def preparar
    @user.assign_attributes(nome: @dados[:nome], email_address: @dados[:email_address])
    @user.assign_attributes(password: @dados[:senha_provisoria], trocar_senha: true) if @user.new_record?
    @vinculo = @user.vinculo || @user.vinculos.build(empresa: Empresa.atual, client: @cliente)
    @vinculo.assign_attributes(funcao: @funcao, acessos_extras: @extras)
  end

  def valido?
    @user.validate
    @user.errors.add(:password, "is required for a new user") if @user.new_record? && @dados[:senha_provisoria].blank?
    @vinculo.validate
    @vinculo.errors.full_messages.each { |erro| @user.errors.add(:base, erro) } unless @vinculo.errors.empty?
    @gestao.erros_de_atribuicao(@user, @funcao, @extras).each { |erro| @user.errors.add(:base, erro) }
    @user.errors.empty?
  end

  def salvar
    User.transaction do
      @user.save!
      @vinculo.save!
    end
  end
end
