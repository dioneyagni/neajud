# What a pedido prints on (Etapa 2.3d1, decided 19/10/2026): the transfer
# paper (calçado, tecido) or the DTF film — the empresa's default unless the
# pedido picks another. A paper of any width (the artes' meters follow it);
# a film only of the default's width, since each size's fit on the film is
# stored for that width (EncaixeDaEtiqueta).
#
# Usage: pedido.material_de_impressao # => the pedido's paper, else Empresa#papel_padrao
#        pedido.largura_do_papel_mm   # => 1600
module MaterialDeImpressaoDoPedido
  extend ActiveSupport::Concern

  included do
    belongs_to :material_impressao, class_name: "MateriaPrima", optional: true
    validate :material_impressao_serve
  end

  def tipo_do_material_de_impressao
    dtf? ? "filme_dtf" : "papel"
  end

  def material_de_impressao
    material_impressao || (dtf? ? Empresa.atual&.filme_dtf_padrao : Empresa.atual&.papel_padrao)
  end

  # The paper width the artes' meters per piece are read on.
  def largura_do_papel_mm
    material_impressao&.largura_mm || Empresa.atual&.largura_papel_efetiva_mm
  end

  # The materials this pedido may print on, among those given.
  # Usage: pedido.materiais_de_impressao_possiveis(visiveis(MateriaPrima))
  def materiais_de_impressao_possiveis(materiais)
    possiveis = materiais.where(tipo: tipo_do_material_de_impressao).includes(:grupo_material, :cor_material).to_a
    return possiveis unless dtf?

    possiveis.select { |filme| filme.largura_mm == Empresa.atual&.largura_filme_dtf_efetiva_mm }
  end

  private

  def material_impressao_serve
    return if material_impressao.nil?
    return errors.add(:material_impressao, "#{material_impressao.nome_completo} is a #{material_impressao.tipo}; a #{Pedido::ROTULOS_DOS_TIPOS[tipo]} pedido prints on a #{tipo_do_material_de_impressao}") if material_impressao.tipo != tipo_do_material_de_impressao
    return unless dtf?

    largura = Empresa.atual&.largura_filme_dtf_efetiva_mm
    errors.add(:material_impressao, "#{material_impressao.nome_completo} is #{material_impressao.largura_mm} mm wide; expected the default film's #{largura} mm (the fits are stored for it)") if material_impressao.largura_mm != largura
  end
end
