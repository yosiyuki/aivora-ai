module Content
  # Generates (or regenerates) one page in the background. The item is
  # claimed first, so two enqueues for the same page produce one version;
  # an LLM failure is recorded as a failed version instead of retried
  # blindly, since a retry would spend the budget again.
  class GenerateJob < ApplicationJob
    queue_as :default

    retry_on ActiveRecord::Deadlocked, ActiveRecord::ConnectionNotEstablished, wait: 5.seconds, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    def perform(site_id, page_type)
      site = Site.find(site_id)
      item, previous_status = ContentItem.claim_for_generation!(site, page_type)
      return unless item

      begin
        version = Content::Generator.new(site, page_type: page_type).generate!
        item.reload.update!(status: previous_status) unless version.passed?
      rescue Llm::Error => e
        item.record_generation_failure!(e, restore_status: previous_status)
      end
    end
  end
end
