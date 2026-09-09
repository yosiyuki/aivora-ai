# An archetype a site has activated. Archetypes compose ("shop info + blog"),
# so a site may have several; exactly one is primary. Activation only ever
# adds structure; it never moves an existing URL.
class SiteArchetype < ApplicationRecord
  belongs_to :site

  validates :archetype, presence: true, uniqueness: { scope: :site_id }
  validate :archetype_is_defined

  scope :primary, -> { where(is_primary: true) }

  def definition = ArchetypeDefinition.find(archetype)

  private

  def archetype_is_defined
    errors.add(:archetype, :undefined) unless ArchetypeDefinition.exists?(archetype)
  end
end
