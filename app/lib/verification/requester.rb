module Verification
  # Turns the blanks in a generated page, and the slots no page has filled yet,
  # into questions the owner can answer (README §14).
  #
  # The blank is the question. A non-expert cannot fill an empty form with
  # entities and facts, but can answer "what are your opening hours?" when the
  # page visibly lacks them.
  class Requester
    # Rank, not a score. `level` says when a slot is needed, so it orders the
    # asking; weight breaks ties within a level. Deliberately not a formula:
    # weight is defined as the Knowledge Health input (DatabaseSchema §65),
    # and inventing a priority coefficient from it would be our arithmetic,
    # not the product's.
    LEVEL_RANK = { "minimum" => 3, "standard" => 2, "enriched" => 1 }.freeze

    def initialize(site)
      @site = site
    end

    # Called after a version is decided. Blanks first, then slots that are
    # simply unfilled: a hole in a published page is more pressing than a
    # subject nobody has written about yet.
    def issue_for(version)
      wanted = blank_slot_keys(version) | unfilled_slot_keys
      VerificationRequest.transaction do
        supersede_gone(wanted)
        wanted.filter_map { |key| issue(key, claim_for(version, key)) }
      end
    end

    private

    # Grounder-decided blanks are claim rows; drafter placeholders live only in
    # the version body and metadata. Both are blanks to the reader, so both
    # have to raise a question.
    def blank_slot_keys(version)
      return [] if version.nil?

      from_claims = version.claims.blanks.pluck(:slot_key).compact
      from_body = version.blank_slot_keys
      from_metadata = Array(version.metadata["blanks"]).filter_map { |b| b["slot_key"] }
      (from_claims | from_body | from_metadata) & slots.keys
    end

    # standard and enriched slots are never asked in the interview (README
    # §27.3); they become questions here. This is the first code to read them.
    def unfilled_slot_keys
      filled = @site.facts.where(status: "accepted").where.not(slot_key: nil).distinct.pluck(:slot_key)
      filled |= @site.current_interview&.filled_slot_keys.to_a
      slots.keys - filled
    end

    def issue(key, claim)
      slot = slots[key] or return nil
      return nil if VerificationRequest.where(site: @site, slot_key: key, status: "open").exists?

      VerificationRequest.create!(
        site: @site, request_type: "initial", slot_key: key, content_claim: claim,
        question: Question.for(slot, statement: claim&.statement), priority: rank(slot)
      )
    end

    # A question whose slot is now answered, or no longer required, stops being
    # asked. It is not deleted — nothing here is (README §23).
    def supersede_gone(wanted)
      VerificationRequest.where(site: @site, request_type: "initial", status: "open")
                         .where.not(slot_key: wanted)
                         .find_each(&:supersede!)
    end

    def claim_for(version, key)
      return nil if version.nil?

      version.claims.blanks.find { |c| c.slot_key == key }
    end

    def rank(slot) = LEVEL_RANK.fetch(slot.level, 0) * 100 + (slot.weight * 10).round

    def slots = @slots ||= @site.required_slots.index_by(&:key)
  end
end
