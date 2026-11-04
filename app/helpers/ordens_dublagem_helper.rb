# The Dublagens page's warnings (Dublagem 5a, decided 03/11/2026): before
# the machine runs, which component the stock doesn't cover — never a block
# (decision 4a: marking it done takes the balance below zero).
module OrdensDublagemHelper
  # Usage: falta_de_componentes(construcao, 10, saldos)
  #   # => "falta componente: Lona Branco-1.40 m da empresa, 4 m; Filme 35 µm-1.60 m da empresa, 10 m"
  def falta_de_componentes(construcao, metros, saldos)
    componentes = ComponentesDaDublagem.new(construcao)
    faltas = componentes.faltas(metros.to_f, saldos).map { |c| "#{c.materia_prima.nome_completo} #{c.client ? "do cliente" : "da empresa"}, #{metros(c.falta)}" }
    faltas << "#{componentes.sem_ligante} ligante a escolher na construção" if componentes.sem_ligante.positive?
    "falta componente: #{faltas.join("; ")}" if faltas.any?
  end

  # Usage: quem_e_quando(ordem.feita_por, ordem.feita_em) # => "Ana · 04/11 14:20"
  def quem_e_quando(user, momento)
    [ user&.nome, momento && l(momento, format: :short) ].compact.join(" · ")
  end
end
