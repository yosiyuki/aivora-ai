# Knowledge is never overwritten silently: every create and every change
# appends a knowledge_versions row with a full snapshot (DatabaseSchema §20).
module Versioned
  extend ActiveSupport::Concern

  included do
    # Versions are kept, never cascaded away. This used to be the only thing
    # stopping a knowledge row from being destroyed, which made the guarantee
    # conditional on the versions still existing — deleting them first made
    # the row deletable again. NeverDeleted states the rule directly now, on
    # the versions as well as the knowledge.
    #
    # All of this guards the ActiveRecord path. Bypass APIs (delete,
    # delete_all, update_all, update_columns, insert_all) skip callbacks, so
    # they are forbidden on knowledge tables; spec/lib/knowledge_bypass_spec.rb
    # fails the build if one appears. Database-level enforcement is #45.
    has_many :knowledge_versions, as: :knowledge, dependent: :restrict_with_exception
    attr_accessor :change_reason, :changed_by

    after_create { record_version!(reason: change_reason || "created") }
    after_update { record_version!(reason: change_reason || "updated") if saved_changes.except("updated_at").any? }
  end

  def record_version!(reason:)
    knowledge_versions.create!(
      version: knowledge_versions.count + 1,
      snapshot: attributes.except("updated_at"),
      change_reason: reason,
      changed_by: changed_by
    )
  end
end
