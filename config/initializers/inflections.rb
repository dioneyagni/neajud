ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "material", "materiais"
  inflect.irregular "funcao", "funcoes"
  inflect.irregular "aprovacao", "aprovacoes"
  inflect.irregular "solicitacao", "solicitacoes"
  inflect.irregular "referencia", "referencias"
end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end
