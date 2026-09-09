# The single site this deployment publishes (1 deployment = 1 customer = 1 site).
# The table keeps the full column set from DatabaseSchema §3 so site_id stays
# meaningful everywhere, but only one row may exist in Phase 1.
class Site < ApplicationRecord
  STATUSES = %w[setup active].freeze
  HOSTNAME = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\z/

  # Accept a pasted URL ("https://example.com/path") and keep only the host.
  normalizes :domain, with: ->(d) { extract_host(d) }

  validates :name, presence: true
  validates :domain, presence: true, format: { with: HOSTNAME, message: :invalid_hostname }
  validates :primary_language, presence: true
  validates :timezone, presence: true, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:name) } }
  validates :status, inclusion: { in: STATUSES }
  validate :only_one_site

  has_many :site_archetypes, dependent: :destroy

  def self.current = first

  # Archetypes are derived from goals (README §28), never chosen by the user.
  # Adding one only adds structure; existing URLs never move.
  def add_archetype(key, primary: false)
    key = key.to_s
    transaction do
      site_archetypes.primary.update_all(is_primary: false) if primary
      record = site_archetypes.find_or_initialize_by(archetype: key)
      record.assign_attributes(is_primary: primary || record.is_primary, activated_at: record.activated_at || Time.current)
      record.save!
      update!(primary_archetype: key) if primary
      record
    end
  end

  def archetype_definitions = site_archetypes.order(is_primary: :desc, activated_at: :asc).map(&:definition)
  def primary_archetype_definition = primary_archetype.presence && ArchetypeDefinition.find(primary_archetype)

  # Union of the slots every active archetype needs. The same key can appear
  # in several definitions (e.g. `name`); the highest weight wins.
  def required_slots(level: nil)
    merged = archetype_definitions.flat_map(&:slots).group_by(&:key).map { |_, group| group.max_by(&:weight) }
    level ? merged.select { |s| s.level == level.to_s } : merged
  end

  def self.extract_host(value)
    value = value.to_s.strip
    value = "//#{value}" unless value.include?("://") || value.start_with?("//")
    (URI.parse(value).host || "").downcase.delete_suffix(".")
  rescue URI::InvalidURIError
    value.downcase
  end

  private

  def only_one_site
    return unless Site.where.not(id: id).exists?

    errors.add(:base, :only_one_site)
  end
end
