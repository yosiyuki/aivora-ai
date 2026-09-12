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
  has_many :sources, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :entities, dependent: :restrict_with_exception
  has_many :entity_candidates, dependent: :restrict_with_exception
  has_many :facts, dependent: :restrict_with_exception
  has_many :claims, dependent: :restrict_with_exception
  has_many :experiences, dependent: :restrict_with_exception
  has_many :questions, dependent: :restrict_with_exception
  has_many :problems, dependent: :restrict_with_exception
  has_many :evidence, dependent: :restrict_with_exception
  has_many :goals, dependent: :restrict_with_exception
  has_many :content_items, dependent: :restrict_with_exception
  belongs_to :primary_entity, class_name: "Entity", optional: true

  def current_interview = interviews.order(:created_at).last
  def top_page = content_items.find_by(archetype_page_type: "top")
  def interview_pending? = current_interview.nil? || !current_interview.completed?

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
  # in several definitions (e.g. `name`); the highest weight wins. The level
  # filter is applied before merging, so a key that is minimum for one
  # archetype is required even if another archetype ranks it lower.
  def required_slots(level: nil)
    archetype_definitions.flat_map { |d| d.slots(level: level) }
                         .group_by(&:key).map { |_, group| group.max_by(&:weight) }
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
