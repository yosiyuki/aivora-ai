# A snapshot of a knowledge row at one point in its life (DatabaseSchema §20).
#
# The audit trail itself, so it is append-only in both directions: a version is
# never rewritten and never removed. This is load-bearing rather than tidy —
# every other knowledge row relies on having at least one version to be
# undeletable, so a deletable version would unlock deleting the knowledge too.
class KnowledgeVersion < ApplicationRecord
  include NeverDeleted

  belongs_to :knowledge, polymorphic: true
  belongs_to :changed_by, polymorphic: true, optional: true

  validates :version, presence: true, uniqueness: { scope: %i[knowledge_type knowledge_id] }

  # A snapshot records what was true then; editing it would make the history
  # disagree with itself.
  def readonly? = persisted?
end
