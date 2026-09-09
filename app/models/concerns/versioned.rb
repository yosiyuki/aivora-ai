# Knowledge is never overwritten silently: every create and every change
# appends a knowledge_versions row with a full snapshot (DatabaseSchema §20).
module Versioned
  extend ActiveSupport::Concern

  included do
    has_many :knowledge_versions, as: :knowledge, dependent: :destroy
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
