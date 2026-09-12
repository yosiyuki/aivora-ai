module Content
  # Generates (or regenerates) one page in the background. The item is
  # claimed first, so two enqueues for the same page produce one version;
  # an LLM failure is recorded as a failed version instead of retried
  # blindly, since a retry would spend the budget again.
  class GenerateJob < ApplicationJob
    queue_as :default

    # Enqueue only after the surrounding transaction commits (Interview#complete!
    # enqueues from inside one). Explicit, not inherited from the adapter.
    self.enqueue_after_transaction_commit = true

    discard_on ActiveRecord::RecordNotFound

    def perform(site_id, page_type)
      site = Site.find(site_id)
      claim = ContentItem.claim_for_generation!(site, page_type) or return
      item, token, previous_status = claim

      begin
        version = Content::Generator.new(site, page_type: page_type).generate!
        item.release_generation!(token, to: version.passed? ? "published" : previous_status)
      rescue StandardError => e
        # Any failure after the claim: record it and hand the row back. An LLM
        # error is not retried blindly — a retry would spend the budget again.
        item.record_generation_failure!(e, token: token, restore_status: previous_status)
      ensure
        item.release_generation!(token, to: previous_status)   # no-op unless still held with this token
      end
    end
  end
end
