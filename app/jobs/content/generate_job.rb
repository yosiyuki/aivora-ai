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

    # knowledge_type / knowledge_id name the subject of a per-item page
    # (article ← Experience, question ← Question); nil for a whole-site page.
    def perform(site_id, page_type, knowledge_type = nil, knowledge_id = nil)
      site = Site.find(site_id)
      knowledge = knowledge_type ? knowledge_type.constantize.find(knowledge_id) : nil
      claim = ContentItem.claim_for_generation!(site, page_type, knowledge: knowledge) or return
      item, token, previous_status = claim

      begin
        version = Content::Generator.new(site, page_type: page_type, knowledge: knowledge).generate!
        if version
          item.release_generation!(token, to: version.passed? ? "published" : previous_status)
          # A new article changes the list page; the list is code, not a model call.
          Content::Lister.refresh!(site) if version.passed? && Content::PageMaterial.item_page?(page_type)
        else
          # Nothing to write from yet: the item stays a draft, no model was
          # called, and the questions below are what will change that.
          item.release_generation!(token, to: previous_status)
        end
        issue_verification_requests(site)
      rescue StandardError => e
        # Any failure after the claim: record it and hand the row back. An LLM
        # error is not retried blindly — a retry would spend the budget again.
        item.record_generation_failure!(e, token: token, restore_status: previous_status)
      ensure
        item.release_generation!(token, to: previous_status)   # no-op unless still held with this token
      end
    end

    private

    # The blanks across the site's pages are the questions to ask the owner
    # (README §14). Site-wide rather than per page, so N pages generated in
    # any order cannot close each other's questions.
    def issue_verification_requests(site)
      Verification::Requester.new(site).issue_for_site
    rescue StandardError => e
      # Never fail a generated page over the follow-up questions.
      Rails.logger.error("verification: could not issue requests: #{e.class}: #{e.message}")
    end
  end
end
