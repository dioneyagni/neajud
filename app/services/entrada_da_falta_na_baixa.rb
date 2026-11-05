# The material missing at a baixa, launched there (decided 05/11/2026): who
# gives the baixa knows the material came in. A stage that takes material
# (EtapasProducao `material`) whose lines leave the pedido waiting for it
# (AguardandoMaterial) asks for the entry first — no baixa without it. Each
# material × owner its lines take gets one entry of at least what frees the
# pedido (`minimo`: its own falta plus the older outs the entries cover
# first); more when more came. Whoever may edit the stock launches it; anyone
# else needs the email and password of someone who may (`autorizador`).
#
# The entry points at the baixa by lancada_na_baixa: undoing the baixa keeps
# it (the material arrived either way).
#
# Usage: faltas = EntradaDaFaltaNaBaixa.faltas(pedido, partes) # => [#<Item materia_prima=Oxford client=nil falta=10.0 minimo=15.0>]
#        EntradaDaFaltaNaBaixa.call(baixa, faltas, entradas: { "<material uuid>:empresa" => "15" }, user: u, autorizador: { email: "", senha: "" })
#   # => nil, or the error ("…")
class EntradaDaFaltaNaBaixa
  Item = Struct.new(:materia_prima, :client, :falta, :minimo, keyword_init: true) do
    # The form's key: "<material uuid>:<client uuid>", or ":empresa".
    def chave
      "#{materia_prima.uuid}:#{client&.uuid || "empresa"}"
    end
  end

  # What the pedido waits for among the materials × owners these parts take
  # (MateriaisDasLinhas), one Item each, its outs summed.
  def self.faltas(pedido, partes)
    donos = partes.to_set { |parte| [ parte.materia_prima.id, parte.client&.id ] }
    AguardandoMaterial.call.do_pedido(pedido).select { |falta| donos.include?([ falta.materia_prima.id, falta.client&.id ]) }
                      .group_by { |falta| [ falta.materia_prima, falta.client ] }
                      .map { |(material, client), grupo| Item.new(materia_prima: material, client: client, falta: grupo.sum(&:metros), minimo: grupo.map(&:para_liberar).max) }
  end

  def self.call(baixa, faltas, **dados)
    new(baixa, faltas, **dados).call
  end

  def initialize(baixa, faltas, entradas:, user:, autorizador: nil)
    @baixa = baixa
    @faltas = faltas
    @entradas = entradas.to_h.transform_keys(&:to_s).transform_values { |valor| valor.to_s.tr(",", ".").strip }
    @user = user
    @autorizador = (autorizador || {}).to_h.transform_keys(&:to_s)
  end

  def call
    erro = erro_das_quantidades || erro_de_autorizacao
    return erro if erro

    @faltas.each { |item| lancar(item) }
    nil
  end

  private

  # No pedido_id: the material is the stock's, it would leave with a trashed pedido.
  def lancar(item)
    MovimentoEstoque.create!(materia_prima: item.materia_prima, client: item.client, da_empresa: item.client.nil?, tipo: "entrada",
                             quantidade: @entradas[item.chave].to_d, lancada_na_baixa: @baixa, lancado_por: @user,
                             autorizado_por: (@quem_autoriza unless @quem_autoriza == @user))
  end

  def erro_das_quantidades
    @faltas.filter_map do |item|
      valor = @entradas[item.chave].to_s
      next "Entry of #{item.materia_prima.nome_completo} #{valor.inspect} is not a number of meters." unless valor.match?(/\A\d+(\.\d+)?\z/)

      "Entry of #{item.materia_prima.nome_completo} #{valor.tr(".", ",")} m is below the #{metros_br(item.minimo)} m missing; expected at least that." if valor.to_d < item.minimo
    end.first
  end

  def erro_de_autorizacao
    @quem_autoriza = pode_editar?(@user) ? @user : autorizador
    "Launching the entry needs the email and password of someone who may edit the stock." unless @quem_autoriza
  end

  def autorizador
    return nil if @autorizador["email"].blank? || @autorizador["senha"].blank?

    outro = User.authenticate_by(email_address: @autorizador["email"], password: @autorizador["senha"])
    outro if outro && User.com_acesso.exists?(outro.id) && pode_editar?(outro)
  end

  def pode_editar?(user)
    user&.autorizacao&.pode?(:estoque, :editar)
  end

  def metros_br(valor)
    format("%.2f", valor).tr(".", ",").delete_suffix(",00")
  end
end
