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

  def self.interview_for(site)
    site.sources.find_or_create_by!(source_type: "interview") do |s|
      s.name = "ヒアリング"
      s.trust_level = "owner"
    end
  end

  def owner? = trust_level == "owner"
end
