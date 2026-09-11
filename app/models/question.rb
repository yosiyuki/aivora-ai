class Question < ApplicationRecord
  include Versioned
  include Evidenced

  belongs_to :site
  belongs_to :entity, optional: true

  validates :text, presence: true
  before_validation { self.first_seen_at ||= Time.current }
  before_validation { self.last_seen_at ||= first_seen_at }

  def seen_again!(at: Time.current) = update!(frequency: frequency + 1, last_seen_at: at)
end
