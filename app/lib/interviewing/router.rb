module Interviewing
  # Writes the Extraction Agent's output to the right tables (README §27.6).
  # Intent goes to goals and never to Knowledge; facts and experiences carry
  # provenance back to the answer's source_item. Pure code, no LLM.
  class Router
    OWNER_PROMOTE_CONFIDENCE = 0.6

    def initialize(interview)
      @interview = interview
      @site = interview.site
    end

    def route!(turn, output)
      item = turn.source_item or raise ArgumentError, "turn #{turn.id} has no source_item"
      @interview.transaction do
        evidence = Evidence.from_source_item!(item, content: turn.answer_text, evidence_type: "statement",
                                              metadata: { "turn_id" => turn.id })
        apply_role(turn, output["role"])
        entity = resolve_primary_entity(item, output["primary_entity"], evidence)
        route_goals(item, output.fetch("goals", []))
        route_facts(item, entity, evidence, output.fetch("facts", []))
        route_experiences(item, entity, evidence, output.fetch("experiences", []))
        route_utterances(entity, evidence, output.fetch("utterances", []))
        @interview.update!(pending_question: normalize_question(output["next_question"]))
      end
    end

    private

    def apply_role(turn, role)
      return unless turn.question_kind == "role" && ExtractionSchema::ROLES.include?(role)

      @site.update!(user_role: role)
    end

    # The interview has one subject (the shop, the person, the topic). Owner
    # statements promote it; anything else would stay a candidate.
    def resolve_primary_entity(item, proposed, evidence)
      return @site.primary_entity if proposed.blank?

      candidate = @site.entity_candidates.create!(candidate_name: proposed["name"], entity_type: proposed["entity_type"],
                                                  source_item: item, confidence: proposed["confidence"].to_f)
      if @site.primary_entity
        @site.primary_entity.add_alias!(proposed["name"], source: "interview", confidence: proposed["confidence"].to_f) if @site.primary_entity.canonical_name != proposed["name"]
        candidate.update!(status: "accepted", proposed_entity: @site.primary_entity)
        return @site.primary_entity
      end
      return nil unless item.owner? && candidate.confidence >= OWNER_PROMOTE_CONFIDENCE

      entity = candidate.promote!
      entity.add_evidence!(evidence)
      @site.update!(primary_entity: entity)
      entity
    end

    def route_goals(item, goals)
      goals.each do |g|
        next if g["statement"].blank?

        @site.goals.create!(name: g["verb"].presence || g["statement"].first(30), description: g["statement"],
                            confidence: g["confidence"].to_f, source_item: item, archetype: @site.primary_archetype)
      end
    end

    def route_facts(item, entity, evidence, facts)
      facts.each do |f|
        next if f["value"].blank?

        @interview.fill_slot!(f["slot"], value: f["value"], source_item_id: item.id, confidence: f["confidence"].to_f) if f["slot"].present?
        next unless entity

        fact = entity.facts.create!(site: @site, attribute_key: f["attribute"].presence || f["slot"] || "unknown",
                                    value_json: { "value" => f["value"] }, confidence: f["confidence"].to_f.clamp(0, 1),
                                    risk_level: risk_for(f["slot"]), change_reason: "extracted from interview")
        fact.accept!(evidence: evidence) if item.owner?   # the owner said it: that is the validation (G6)
      end
    end

    def route_experiences(item, entity, evidence, experiences)
      experiences.each do |e|
        next if e["summary"].blank?

        exp = @site.experiences.create!(entity: entity, summary: e["summary"], body: e["quote"].presence || e["summary"],
                                        person_id: "owner", metadata: { "source_item_id" => item.id })
        exp.add_evidence!(evidence)
        @interview.fill_slot!(e["slot"], value: e["summary"], source_item_id: item.id, confidence: e["confidence"].to_f) if e["slot"].present?
      end
    end

    def route_utterances(entity, evidence, utterances)
      utterances.each do |u|
        case u["kind"]
        when "question" then @site.questions.create!(entity: entity, text: u["text"], language: "ja").add_evidence!(evidence)
        when "problem" then @site.problems.create!(entity: entity, text: u["text"], confidence: u["confidence"].to_f).add_evidence!(evidence)
        end
        # intent -> goals (handled above); fact/experience -> handled above; offtopic -> evidence only
      end
    end

    def risk_for(slot)
      %w[hours location contact].include?(slot.to_s) ? "high" : "medium"
    end

    def normalize_question(q)
      return nil unless q.is_a?(Hash) && q["text"].present? && q["examples"].is_a?(Array) && q["examples"].size == 3

      q.slice("text", "examples", "targets_slot", "quotes_user")
    end
  end
end
