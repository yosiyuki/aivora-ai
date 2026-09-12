class KnowledgeVersion < ApplicationRecord
  belongs_to :knowledge, polymorphic: true
  belongs_to :changed_by, polymorphic: true, optional: true

  validates :version, presence: true, uniqueness: { scope: %i[knowledge_type knowledge_id] }
end
