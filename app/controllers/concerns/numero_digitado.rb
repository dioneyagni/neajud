# A decimal as typed in Brazil: "4,50" → "4.50"; blank → nil (not set).
# Usage: decimal_digitado(params[:preco]) # => "4.50"
module NumeroDigitado
  private

  def decimal_digitado(valor)
    valor.to_s.strip.tr(",", ".").presence
  end
end
