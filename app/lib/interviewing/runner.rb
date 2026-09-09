module Interviewing
  # Drives one interview: hands out the current question, records answers as
  # both conversational state and raw external input, and decides when to
  # stop. Termination is code, not the model: minimum slots filled, or the
  # question cap.
  class Runner
    attr_reader :interview

    def initialize(interview, question_source: FixedQuestionSource.new)
      @interview = interview
      @question_source = question_source
    end

    # The unanswered turn to show; created on demand so a browser that comes
    # back later lands on exactly the same question.
    def current_turn
      return nil unless interview.in_progress?

      interview.current_turn || build_next_turn
    end

    def answer!(text)
      text = text.to_s.strip
      raise ArgumentError, "answer is blank" if text.blank?

      turn = current_turn or raise ArgumentError, "interview is not accepting answers"
      interview.transaction do
        item = Source.interview_for(interview.site).source_items.create!(
          external_id: "interview-turn-#{turn.id}",
          raw_content: text,
          metadata: { "turn_id" => turn.id, "question_kind" => turn.question_kind, "question_text" => turn.question_text }
        )
        turn.update!(answer_text: text, answered_at: Time.current, source_item: item)
        interview.increment!(:question_count)
        interview.update!(status: "ready") if interview.ready_to_generate?
      end
      turn
    end

    def can_finish? = interview.ready_to_generate? || interview.capped? || interview.turns.count(&:answered?) >= 3
    def capped? = interview.capped?

    # Progress without naming slots (README §27.7).
    def progress_key
      if interview.ready_to_generate? then "ready"
      elsif interview.capped? then "capped"
      elsif interview.minimum_slot_keys.present? && interview.missing_minimum_slot_keys.size <= 1 then "almost"
      else "collecting"
      end
    end

    private

    def build_next_turn
      return nil if interview.capped?

      question = @question_source.next_question(interview) or return nil
      interview.turns.create!(position: interview.turns.size + 1, question_text: question.text,
                              examples: question.examples, question_kind: question.kind)
    end
  end
end
