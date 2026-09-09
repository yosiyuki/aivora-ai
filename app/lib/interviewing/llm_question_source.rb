module Interviewing
  # Serves the question the Extraction Agent proposed for the previous answer,
  # falling back to the fixed questions when there is none (first turns, or an
  # extraction failure). Examples are validated here: exactly three, or it is
  # not used.
  class LlmQuestionSource < QuestionSource
    def initialize(fallback: FixedQuestionSource.new)
      @fallback = fallback
    end

    def next_question(interview)
      pending = interview.pending_question
      if pending.is_a?(Hash) && pending["text"].present? && pending["examples"].is_a?(Array) && pending["examples"].size == 3
        kind = pending["kind"].presence || (pending["targets_slot"].present? ? "slot:#{pending["targets_slot"]}" : "open")
        return Question.new(text: pending["text"], examples: pending["examples"], kind: kind)
      end
      @fallback.next_question(interview)
    end
  end
end
