class EvidenceLink < ApplicationRecord
  RELATIONS = %w[supports contradicts mentions].freeze

  belongs_to :evidence
  belongs_to :knowledge, polymorphic: true

  validates :relation_type, inclusion: { in: RELATIONS }
  validate :same_site

  private

  # Provenance never crosses a tenant boundary.
  def same_site
    return if evidence.nil? || knowledge.nil? || evidence.site_id == knowledge.site_id

    errors.add(:evidence, :other_site)
  end
end
