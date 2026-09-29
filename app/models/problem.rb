class Problem < ApplicationRecord
  include Versioned
  include Evidenced
  include SameSite
  include NeverDeleted

  SEVERITIES = %w[low medium high].freeze

  belongs_to :site
  belongs_to :entity, optional: true
  same_site_as :entity

  validates :text, presence: true
  validates :severity, inclusion: { in: SEVERITIES }, allow_nil: true
end
