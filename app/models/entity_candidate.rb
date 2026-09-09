# An entity the Extraction Agent proposed (DatabaseSchema §10). Extraction
# alone does not create truth: a candidate becomes an Entity only through
# promote!, which is a code decision based on source trust.
class EntityCandidate < ApplicationRecord
  STATUSES = %w[pending accepted rejected].freeze

  belongs_to :site
  belongs_to :source_item, optional: true
  belongs_to :proposed_entity, class_name: "Entity", optional: true

  validates :candidate_name, presence: true
  validates :entity_type, inclusion: { in: Entity::TYPES }
  validates :status, inclusion: { in: STATUSES }

  before_validation { self.site ||= source_item&.site }

  def pending? = status == "pending"

  def promote!(changed_by: nil)
    transaction do
      entity = proposed_entity || site.entities.find_by(canonical_name: candidate_name, entity_type: entity_type) ||
               site.entities.create!(entity_type: entity_type, canonical_name: candidate_name, changed_by: changed_by,
                                     change_reason: "promoted from candidate #{id}")
      update!(status: "accepted", proposed_entity: entity)
      entity
    end
  end

  def reject! = update!(status: "rejected")
end
