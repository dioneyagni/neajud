# 09/10/2026: draft items' parts now follow their arte and molde
# (RecomporRascunhos), but only from the next change on. This brings the
# drafts that already exist up to date once (e.g. 42e40535's "Sem peça" next
# to an empty Cabedal). Safe to repeat; confirmed pedidos are not touched.
#
# Usage: bin/rails pedidos:recompor_rascunhos
namespace :pedidos do
  desc "Rebuild the parts of every draft pedido's items from their arte and molde"
  task recompor_rascunhos: :environment do
    puts "Rebuilt the parts of #{RecomporRascunhos.todos} draft items."
  end
end
