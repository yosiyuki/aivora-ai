class Problem < ApplicationRecord
  include Evidenced

  SEVERITIES = %w[low medium high].freeze

  belongs_to :site
  belongs_to :entity, optional: true

  validates :text, presence: true
  validates :severity, inclusion: { in: SEVERITIES }, allow_nil: true
end
