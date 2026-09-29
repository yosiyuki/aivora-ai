# A canonical thing the site talks about: the shop, the person, a topic
# (DatabaseSchema §8). Facts hang off entities.
class Entity < ApplicationRecord
  include Versioned
  include Evidenced
  include NeverDeleted

  TYPES = %w[business person topic project place product].freeze
  STATUSES = %w[active merged retired].freeze

  belongs_to :site
  # Nothing here cascades. An entity that has knowledge attached cannot be
  # removed, and its knowledge is never quietly detached either: nullifying
  # entity_id would strip a fact of its subject while leaving the row in
  # place, which loses information without recording that anything happened.
  # Combining entities is MERGE (README §23), not severed references.
  has_many :entity_aliases, dependent: :restrict_with_exception
  has_many :facts, dependent: :restrict_with_exception
  has_many :claims, dependent: :restrict_with_exception
  has_many :experiences, dependent: :restrict_with_exception

  validates :entity_type, inclusion: { in: TYPES }
  validates :canonical_name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :site_id }
  validates :status, inclusion: { in: STATUSES }

  before_validation :assign_slug, on: :create

  def add_alias!(name, language: nil, source: nil, confidence: nil)
    entity_aliases.find_or_create_by!(alias: name) { |a| a.assign_attributes(language:, source:, confidence:) }
  end

  private

  # Japanese names parameterize to an empty string; fall back to a stable id.
  def assign_slug
    return if slug.present?

    base = canonical_name.to_s.parameterize
    base = "entity" unless base.match?(/[a-z]/)
    candidate = base
    n = 1
    candidate = "#{base}-#{n += 1}" while site && site.entities.exists?(slug: candidate)
    self.slug = candidate
  end
end
