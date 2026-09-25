class EntityAlias < ApplicationRecord
  include NeverDeleted

  belongs_to :entity
  validates :alias, presence: true, uniqueness: { scope: :entity_id }
end
