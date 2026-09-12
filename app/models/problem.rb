class Problem < ApplicationRecord
  include Versioned
  include Evidenced
  include SameSite

  SEVERITIES = %w[low medium high].freeze

  belongs_to :site
  belongs_to :entity, optional: true
  same_site_as :entity

  validates :text, presence: true
  validates :severity, inclusion: { in: SEVERITIES }, allow_nil: true
end
