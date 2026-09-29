# Nothing is physically deleted (README §23, DatabaseSchema §1).
#
# This is what makes autonomous operation without human approval recoverable:
# with no per-action review, an irreversible operation cannot exist in the
# system. Unpublishing, retiring and superseding all keep the row.
#
# Including this states the intent. Several models were previously protected
# only as a side effect of `dependent: :restrict_with_exception` — a fact was
# undeletable because it happened to have a knowledge_versions row, so
# deleting the versions first made the fact deletable again. That is not a
# guarantee, it is a coincidence.
#
# This guards the ActiveRecord path. `delete`, `delete_all` and raw SQL skip
# callbacks entirely; spec/lib/knowledge_bypass_spec.rb keeps them out of the
# codebase, and database triggers are tracked in #45.
module NeverDeleted
  extend ActiveSupport::Concern

  included do
    before_destroy { raise ActiveRecord::RecordNotDestroyed.new("#{self.class.name} rows are never physically deleted", self) }
  end
end
