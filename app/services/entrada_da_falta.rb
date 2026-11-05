# The material missing, launched where the operator sees it (decided
# 05/11/2026): who gives the baixa, or delivers the pedido, knows the material
# came in.
#   at the baixa   — a stage that takes material (EtapasProducao `material`)
#     whose lines leave the pedido waiting (AguardandoMaterial) for a material
#     they take: no baixa without the entry;
#   at the delivery — every material the pedido still waits for: delivered,
#     it would stop showing as waiting with the stock short (#d4f30331 was
#     delivered skipping its Calandra, the one stage that took its fabric).
# Each material × owner gets one entry of at least what frees the pedido
# (`minimo`: its own falta plus the older outs the entries cover first);
# more when more came. Whoever may edit the stock launches it; anyone else
# needs the email and password of someone who may (`autorizador`).
#
# The entry points at where it was launched (lancada_na_baixa or
# lancada_na_entrega): undoing the baixa keeps it — the material arrived.
#
# Usage: faltas = EntradaDaFalta.faltas(pedido, partes) # => [#<Item materia_prima=Oxford client=nil falta=10.0 minimo=15.0>]
#        EntradaDaFalta.call(faltas, origem: { lancada_na_baixa: baixa }, entradas: { "<material uuid>:empresa" => "15" },
#                            user: u, autorizador: { email: "", senha: "" })
#   # => nil, or the error ("…")
class EntradaDaFalta
  Item = Struct.new(:materia_prima, :client, :falta, :minimo, keyword_init: true) do
    # The form's key: "<material uuid>:<client uuid>", or ":empresa".
    def chave
      "#{materia_prima.uuid}:#{client&.uuid || "empresa"}"
    end

    # What the dialog shows (the baixa and entrega Stimulus controllers).
    def para_o_dialogo
      { chave: chave, material: materia_prima.nome_completo, dono: client&.name || "Empresa", falta: falta.to_f, minimo: minimo.to_f }
    end
  end

  # What the pedido waits for, one Item per material × owner, its outs
  # summed; with `partes` (MateriaisDasLinhas), only those they take.
  def self.faltas(pedido, partes = nil)
    donos = partes&.to_set { |parte| [ parte.materia_prima.id, parte.client&.id ] }
    AguardandoMaterial.call.do_pedido(pedido).select { |falta| donos.nil? || donos.include?([ falta.materia_prima.id, falta.client&.id ]) }
                      .group_by { |falta| [ falta.materia_prima, falta.client ] }
                      .map { |(material, client), grupo| Item.new(materia_prima: material, client: client, falta: grupo.sum(&:metros), minimo: grupo.map(&:para_liberar).max) }
  end

  def self.call(faltas, **dados)
    new(faltas, **dados).call
  end

  def initialize(faltas, origem:, entradas:, user:, autorizador: nil)
    @faltas = faltas
    @origem = origem
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
                             quantidade: @entradas[item.chave].to_d, lancado_por: @user,
                             autorizado_por: (@quem_autoriza unless @quem_autoriza == @user), **@origem)
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
