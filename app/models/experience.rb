# Something the owner (or a person) lived through, kept in their own words.
# This is what Experiential Claims are written from (README §20, §27.1).
class Experience < ApplicationRecord
  include Versioned
  include Evidenced
  include SameSite

  belongs_to :site
  belongs_to :entity, optional: true
  same_site_as :entity

  validates :summary, presence: true
end
