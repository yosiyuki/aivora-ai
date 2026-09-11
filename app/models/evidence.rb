# A unit of grounds for knowledge, cut from a raw source item (DatabaseSchema §6).
# Immutable where possible: never edited, only linked.
class Evidence < ApplicationRecord
  TYPES = %w[statement quote document observation].freeze

  belongs_to :site
  belongs_to :source_item
  has_many :evidence_links, dependent: :restrict_with_exception

  validates :evidence_type, inclusion: { in: TYPES }
  validates :content, presence: true
  validates :trust_level, inclusion: { in: Source::TRUST_LEVELS }

  before_validation { self.trust_level ||= source_item&.trust_level }
  before_validation { self.observed_at ||= source_item&.fetched_at || Time.current }
  before_validation { self.site ||= source_item&.site }

  def self.from_source_item!(item, content:, evidence_type: "statement", metadata: {})
    create!(source_item: item, content: content, evidence_type: evidence_type, metadata: metadata)
  end

  def owner? = trust_level == "owner"

  # Once written, evidence is neither edited nor deleted.
  def readonly? = persisted?
end
