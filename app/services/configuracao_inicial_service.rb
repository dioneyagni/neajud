# First access to an instance (Etapa 0.5): creates the empresa, the first
# user and their vínculo as dono, all or nothing. Refused once any user
# exists, so the setup screen can't be used to take over an instance.
#
# Usage: user = ConfiguracaoInicialService.call(empresa_nome: "Sublimação X", nome: "Ana",
#                                                email_address: "ana@x.com", password: "…")
#        user.persisted? # => false with user.errors when invalid
class ConfiguracaoInicialService
  class JaConfigurada < StandardError; end

  def self.call(empresa_nome:, nome:, email_address:, password:)
    new(empresa_nome, User.new(nome: nome, email_address: email_address, password: password)).call
  end

  def initialize(empresa_nome, user)
    @empresa = Empresa.new(nome: empresa_nome)
    @user = user
  end

  def call
    raise JaConfigurada, "instance already configured (#{User.count} user(s)); expected none" if User.exists?
    return @user unless valido?

    ActiveRecord::Base.transaction do
      @empresa.save!
      @user.save!
      Vinculo.create!(user: @user, empresa: @empresa, perfis: %w[dono])
    end
    @user
  end

  private

  # Validates both and puts the empresa's errors on the user (as
  # empresa_nome), so the one form shows everything at once.
  def valido?
    @user.validate
    @empresa.validate
    @empresa.errors.each { |erro| @user.errors.add(:empresa_nome, erro.message) }
    @user.errors.empty?
  end
end
