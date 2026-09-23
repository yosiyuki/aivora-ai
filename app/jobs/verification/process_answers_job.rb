module Verification
  # Turns recorded answers into Knowledge.
  #
  # Answers arrive asynchronously by design: the admin form is the only channel
  # in Phase 1, but README §14 has them coming back through Slack / LINE /
  # Email, and TechnicalArchitecture §36 lists "Hourly Verification Response
  # Processing" as scheduled work. Keeping extraction here means a new channel
  # only has to write a VerificationEvent.
  class ProcessAnswersJob < ApplicationJob
    queue_as :default

    def perform(event_id = nil)
      events = event_id ? VerificationEvent.where(id: event_id) : VerificationEvent.pending_extraction
      events.find_each do |event|
        processed = AnswerProcessor.new(event).process!
        regenerate_affected(event) if processed
      end
    end

    private

    # Affected Content Detection (TechnicalArchitecture §18): only the pages
    # whose blank this answer filled are rebuilt. Regenerating everything would
    # spend budget on pages the answer did not touch (#7).
    def regenerate_affected(event)
      request = event.verification_request
      slot_key = request.slot_key
      return if slot_key.blank?

      page_types(request.site, slot_key).each do |page_type|
        Content::GenerateJob.perform_later(request.site_id, page_type)
      end
    end

    # A blank reaches the page two ways: the Grounder writes a claim row, and
    # the drafter's own [[slot:key]] placeholder survives into the body with no
    # claim behind it. Looking only at claims would miss the second kind, which
    # is exactly the sort this fixture produces.
    def page_types(site, slot_key)
      from_claims = ContentClaim.blanks.where(slot_key: slot_key)
                                .joins(content_version: :content_item)
                                .where(content_items: { site_id: site.id })
                                .distinct.pluck("content_items.archetype_page_type")

      from_body = ContentVersion.joins(:content_item)
                                .where(content_items: { site_id: site.id })
                                .where("body LIKE ?", "%[[slot:#{slot_key}]]%")
                                .distinct.pluck("content_items.archetype_page_type")

      (from_claims | from_body)
    end
  end
end
