# The texts of the construção's chave (Dublagem 5b1a, canvas "4 · Construção
# em dublagens"), each card's small line under its price.
module ConstrucoesHelper
  # What the card's dublagem waits for, where the estampa goes and what the
  # network says of its pair.
  # Usage: texto_da_dublagem(dub_d, nil) # => "espera a Calandra + DUB-C · pela rede: Cola, depois da estampa"
  def texto_da_dublagem(dublagem, situacao)
    partes = [ ("a estampa vai aqui" if dublagem.recebe_estampa?), espera_da_dublagem(dublagem) ]
    partes << (dublagem.letras_usadas.any? ? "sem a superfície" : "sem a superfície, corre em paralelo") unless dublagem.superficie?
    partes << "pela rede: #{dublagem.ligacao.ligantes_na(situacao).map(&:descricao).join(" ou ")}, #{dublagem.ligacao.momentos.join(" ou ")} da estampa" if dublagem.ligacao
    partes.compact.join(" · ")
  end

  # Dublagem 5b1c1: an item's letras by the stage that makes them.
  # Usage: letras_no_pedido(item) # => "DUB-A, DUB-B, DUB-C (Dublagem) · DUB-D (Dublagem final)"
  def letras_no_pedido(item)
    item.letras_da_dublagem.group_by(&:momento_real).sort.map do |momento, letras|
      "#{letras.map(&:letra).join(", ")} (#{momento == "antes" ? "Dublagem" : "Dublagem final"})"
    end.join(" · ")
  end

  # The superfície's letra still before the Calandra is the Calandra's to
  # wait for: it prints on it.
  def espera_da_dublagem(dublagem)
    letras = dublagem.letras_usadas
    calandra = dublagem.momento_real == "depois" && dublagem.letra_com_superficie&.momento_real != "depois"
    letras -= [ dublagem.letra_com_superficie ] if calandra
    return "espera a Calandra#{letras.map { |letra| " + #{letra.letra}" }.join}" if calandra
    return if letras.empty?

    "depois do #{letras.map(&:letra).join(" e do ")}"
  end
end
