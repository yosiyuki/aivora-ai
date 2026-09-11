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

  # Idempotent for an accepted candidate; a rejected one stays rejected.
  # Resolution by (site, type, name) rides on the unique index, so two
  # workers promoting the same name cannot create two entities.
  def promote!(changed_by: nil)
    return proposed_entity if status == "accepted" && proposed_entity
    raise ArgumentError, "candidate #{id} was rejected and cannot be promoted" if status == "rejected"

    transaction do
      entity = proposed_entity || site.entities.create_or_find_by!(entity_type: entity_type, canonical_name: candidate_name) do |e|
        e.changed_by = changed_by
        e.change_reason = "promoted from candidate #{id}"
      end
      update!(status: "accepted", proposed_entity: entity)
      entity
    end
  end

  def reject! = update!(status: "rejected")
end
