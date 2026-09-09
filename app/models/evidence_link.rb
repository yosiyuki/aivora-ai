class EvidenceLink < ApplicationRecord
  RELATIONS = %w[supports contradicts mentions].freeze

  belongs_to :evidence
  belongs_to :knowledge, polymorphic: true

  validates :relation_type, inclusion: { in: RELATIONS }
end
