# Where external input comes from (DatabaseSchema §4). Every connector is
# optional; the interview is just another source with owner-level trust.
class Source < ApplicationRecord
  TRUST_LEVELS = %w[owner trusted external].freeze
  SOURCE_TYPES = %w[interview website slack notion sns wordpress].freeze

  belongs_to :site
  has_many :source_items, dependent: :restrict_with_exception

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :trust_level, inclusion: { in: TRUST_LEVELS }
  validates :name, presence: true

  INTERVIEW_ATTRIBUTES = { name: "ヒアリング", trust_level: "owner", enabled: true }.freeze

  # The reserved interview source. create_or_find_by! rides on the partial
  # unique index, so a concurrent first answer cannot create two; the owner
  # trust level is enforced on every lookup, not only on creation.
  def self.interview_for(site)
    source = site.sources.create_or_find_by!(source_type: "interview") { |s| s.assign_attributes(INTERVIEW_ATTRIBUTES) }
    source.update!(INTERVIEW_ATTRIBUTES) unless INTERVIEW_ATTRIBUTES.all? { |k, v| source.public_send(k) == v }
    source
  end

  def owner? = trust_level == "owner"
end
