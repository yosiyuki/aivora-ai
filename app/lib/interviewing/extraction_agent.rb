module Interviewing
  # One structured call per answer (README §27 / parent plan G1). Tools are
  # impossible by construction: Llm::Client#extract has no such parameter.
  class ExtractionAgent
    PROMPT_DIR = Rails.root.join("app/prompts/interview")
    CONTEXT_TURNS = 8

    def initialize(interview, client: Llm::Client.for(:extraction))
      @interview = interview
      @client = client
    end

    def call(turn)
      slot_keys = all_slot_keys
      @client.extract(system: system_prompt, input: input_for(turn),
                      schema: ExtractionSchema.build(slot_keys: slot_keys), related: turn.source_item)
    end

    def system_prompt
      base = PROMPT_DIR.join("system.txt").read
      role_note = role_prompt
      base
        .sub("{{SLOTS}}", slots_block)
        .sub("{{HYPOTHESIS}}", hypothesis_block)
        .sub("{{MISSING}}", missing_block)
        .then { |t| role_note ? "#{t}\n\n# 相手について\n#{role_note}" : t }
    end

    private

    def input_for(turn)
      previous = @interview.turns.select(&:answered?).reject { |t| t == turn }.last(CONTEXT_TURNS)
      context = previous.map { |t| "Q(#{t.question_kind}): #{t.question_text}\nA: #{t.answer_text}" }.join("\n\n")
      <<~TEXT
        # これまでのやりとり
        #{context.presence || "（まだありません）"}

        # 今回の質問
        Q(#{turn.question_kind}): #{turn.question_text}

        # 今回の答え
        #{turn.answer_text}
      TEXT
    end

    def role_prompt
      role = @interview.site.user_role.presence or return nil
      path = PROMPT_DIR.join("role_#{role}.txt")
      path.exist? ? path.read.strip : nil
    end

    def all_slot_keys
      ArchetypeDefinition.all.flat_map { |d| d.slots.map(&:key) }.uniq
    end

    def slots_block
      ArchetypeDefinition.all.map do |d|
        "- #{d.archetype}（#{d.label}）: " + d.slots.map { |s| "#{s.key}=#{s.label}[#{s.level}/#{s.kind}]" }.join(", ")
      end.join("\n")
    end

    def hypothesis_block
      if @interview.archetype_hypothesis.present?
        "archetype=#{@interview.archetype_hypothesis}（確信度 #{@interview.archetype_confidence&.round(2)}）"
      else
        "まだありません"
      end
    end

    def missing_block
      missing = @interview.missing_minimum_slot_keys
      missing.empty? ? "なし（十分な情報が揃っています）" : missing.join(", ")
    end
  end
end
