ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "material", "materiais"
  inflect.irregular "funcao", "funcoes"
  inflect.irregular "aprovacao", "aprovacoes"
  inflect.irregular "solicitacao", "solicitacoes"
  inflect.irregular "referencia", "referencias"
  # Etapa 2.5a: "-ia" took the "data" rule (plural "sequencia").
  inflect.irregular "sequencia", "sequencias"
  # Dublagem 3/5.
  inflect.irregular "construcao", "construcoes"
  # Dublagem 5a: /dublagens, the ordens de dublagem.
  inflect.irregular "dublagem", "dublagens"
  # Painel 2/4a: /parametros/excecoes, the calendar's exceptions.
  inflect.irregular "excecao", "excecoes"
  # Rede editável 2/2a: /rede-de-dublagens/ligacoes.
  inflect.irregular "ligacao", "ligacoes"
end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end
