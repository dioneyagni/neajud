# Joins one arte into another (Etapa 1.2, 2/3): every file of the origin —
# trashed ones too, so a restore lands in the right arte — moves to the
# destination and takes its molde, client, referência and nome. For files
# grouped apart by mistake (the upload separates by the leading number:
# "863-ARCOVERDE-P" and "864-ARCOVERDE-M" arrive as two artes, decided
# 02/10/2026) and for the same arte uploaded later in another size.
#
# Refused when it would move files to another molde or client: a file already
# linked to them (and maybe to a pedido) must be moved on purpose, from its
# own page.
#
# Usage: JuntarArtesService.call(origem: arquivo, destino: outro) # => destino.arte
class JuntarArtesService
  class Recusado < StandardError; end

  def self.call(origem:, destino:)
    new(origem, destino).call
  end

  # Why joining would be refused, or nil — to check several origins before
  # moving any (ArteArquivosController#trazer).
  # Usage: JuntarArtesService.erro(origem: m, destino: p) # => nil
  def self.erro(origem:, destino:)
    new(origem, destino).send(:validar!)
    nil
  rescue Recusado => e
    e.message
  end

  def initialize(origem, destino)
    @origem = origem
    @destino = destino
  end

  def call
    validar!
    Arquivo.where(arte_id: @origem.arte_id).update_all(arte_id: @destino.arte_id, updated_at: Time.current)
    @destino.compartilhar_com_a_arte!
    @destino.arte
  end

  private

  def validar!
    raise Recusado, "#{@origem.filename.inspect} and #{@destino.filename.inspect} must both be artes; got #{[ @origem.category, @destino.category ].inspect}" unless [ @origem, @destino ].all? { |a| a.arte_id && !a.corte? }
    raise Recusado, "#{@origem.filename.inspect} is already in this arte" if @origem.arte_id == @destino.arte_id
    recusar_diferenca(:molde, @origem.molde&.nome, @destino.molde&.nome) if @origem.molde_id && @origem.molde_id != @destino.molde_id
    recusar_diferenca(:client, @origem.client&.name, @destino.client&.name) if @origem.client_id && @origem.client_id != @destino.client_id
  end

  def recusar_diferenca(campo, de, para)
    raise Recusado, "#{@origem.filename.inspect} is in #{campo} #{de.inspect} and this arte in #{para.inspect}; expected the same #{campo}, or none on #{@origem.filename.inspect}"
  end
end
