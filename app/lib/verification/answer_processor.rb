module Verification
  # An answer becomes Knowledge the same way an interview answer does:
  # SourceItem -> Evidence -> one structured extraction -> a code-side check
  # that the model quoted the owner -> Fact#accept! or Fact#supersede!.
  #
  # Agent Isolation has no exception here (TechnicalArchitecture §7): the
  # reply is untrusted text whatever channel it arrived through.
  class AnswerProcessor
    def initialize(event, agent: nil)
      @event = event
      @request = event.verification_request
      @site = @request.site
      @agent = agent
    end

    def process!
      return false unless @event.claim_for_extraction!

      item = store_answer!
      output = agent.call(@event)
      apply!(output, item)
      @event.update_extraction!(:done, source_item: item)
      true
    rescue StandardError => e
      # The answer is already durable; only the extraction failed, so it can be
      # retried without asking the owner again.
      Rails.logger.error("verification: extraction failed for event #{@event.id}: #{e.class}: #{e.message}")
      @event.update_extraction!(:failed)
      false
    end

    private

    def agent = @agent ||= AnswerAgent.new(@request)

    # Durable before the model runs, so a model failure never loses the words.
    def store_answer!
      item = Source.verification_for(@site).source_items.create!(
        external_id: "verification-event-#{@event.id}",
        raw_content: @event.notes.to_s,
        metadata: { "verification_request_id" => @request.id, "slot_key" => @request.slot_key,
                    "question" => @request.question, "person_id" => @event.person_id }
      )
      @event.update_extraction!(:processing, source_item: item)
      item
    end

    def apply!(output, item)
      return unless output["answered"]

      value = output["value"].to_s
      return if value.blank?

      entity = @site.primary_entity or return

      # The model's word is not the owner's word. Without a verbatim span the
      # value is recorded as a candidate and fills no slot (README §27.6).
      span = grounded_span(output["source_text"], @event.notes.to_s)
      trusted = span.present? && item.owner?

      evidence = Evidence.from_source_item!(item, content: @event.notes.to_s,
                                            metadata: { "verification_request_id" => @request.id })
      write_fact!(entity, value, output, evidence, trusted: trusted)
    end

    # An existing accepted fact for this slot is superseded rather than edited,
    # so the old value keeps its validity window (README §23). supersede!
    # accepts the replacement itself, which is why only the create path calls
    # accept! here.
    def write_fact!(entity, value, output, evidence, trusted:)
      value_json = { "value" => value, "source_text" => output["source_text"] }
      existing = existing_fact(entity)

      # The same value, confirmed again: re-accepting moves last_verified_at
      # and brings a stale fact back into publication without a new row.
      return existing.accept!(evidence: evidence) if existing && trusted && unchanged?(existing, value)
      return existing.supersede!(value_json, evidence: evidence) if existing && trusted

      fact = entity.facts.create!(site: @site, attribute_key: label_for_slot, slot_key: @request.slot_key,
                                  value_json: value_json, confidence: confidence(output),
                                  risk_level: existing&.risk_level || "medium",
                                  change_reason: "answered verification request #{@request.id}")
      fact.accept!(evidence: evidence) if trusted
      fact
    end

    # A recheck names the fact it is about. Otherwise take whichever fact holds
    # this slot — including a stale one, which `current` excludes and which
    # would otherwise be left behind as a duplicate.
    def existing_fact(entity)
      return @request.fact if @request.fact&.entity_id == entity.id

      entity.facts.where(status: %w[accepted stale]).for_slot(@request.slot_key)
            .where("valid_until IS NULL OR valid_until > ?", Time.current).first
    end

    def unchanged?(fact, value)
      Content::TextNormalizer.normalize(fact.value.to_s) == Content::TextNormalizer.normalize(value)
    end

    def label_for_slot
      @site.required_slots.find { |s| s.key == @request.slot_key }&.label || @request.slot_key
    end

    def confidence(output) = output["confidence"].to_f.clamp(0.0, 1.0)

    def grounded_span(source_text, raw)
      span = Content::TextNormalizer.normalize(source_text)
      return nil if span.blank?

      Content::TextNormalizer.normalize(raw).include?(span) ? span : nil
    end
  end
end
