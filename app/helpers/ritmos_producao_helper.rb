# Numbers of the rhythm page as typed in Brazil (Painel 2/4a2).
module RitmosProducaoHelper
  # Usage: numero_br(5.5) # => "5,5"; numero_br(nil) # => nil
  def numero_br(valor, casas = 2)
    valor && number_with_precision(valor, precision: casas, separator: ",", strip_insignificant_zeros: true)
  end

  # Usage: percentual_br(0.625) # => "63%"
  def percentual_br(fracao)
    "#{(fracao * 100).round}%"
  end
end
