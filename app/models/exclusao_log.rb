# One deletion or restore of an Excluivel record (Etapa 0.4). The label is
# copied so /lixeira history stays readable; changed_by is the IP until
# Etapa 0.5 brings users (then deleted_by_id/restored_by_id take over).
class ExclusaoLog < ApplicationRecord
  ACOES = %w[excluido restaurado].freeze

  belongs_to :registro, polymorphic: true

  validates :acao, inclusion: { in: ACOES }
  validates :registro_rotulo, presence: true
end
