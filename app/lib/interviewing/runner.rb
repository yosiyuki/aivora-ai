module Interviewing
  # Drives one interview: hands out the current question, records answers as
  # both conversational state and raw external input, and decides when to
  # stop. Termination is code, not the model: minimum slots filled, or the
  # question cap.
  class Runner
    attr_reader :interview

    def initialize(interview, question_source: LlmQuestionSource.new)
      @interview = interview
      @question_source = question_source
    end

    # The unanswered turn to show; created on demand so a browser that comes
    # back later lands on exactly the same question.
    def current_turn
      return nil unless interview.accepting_answers?

      interview.current_turn || build_next_turn
    end

    class StaleTurn < ArgumentError; end

    # Records an answer against the turn the user was shown. The interview row
    # is locked for the write, so a double submit records once and returns the
    # already-answered turn; a submit for an older question is rejected.
    def answer!(text, turn_id: nil)
      text = text.to_s.strip
      raise ArgumentError, "answer is blank" if text.blank?

      current_turn or raise ArgumentError, "interview is not accepting answers"
      interview.transaction do
        interview.lock!
        turns = interview.turns.reload
        if turn_id
          shown = turns.find { |t| t.id == turn_id.to_i } or raise StaleTurn, "turn #{turn_id} is not part of this interview"
          return shown if shown.answered? && shown.answer_text == text
          raise StaleTurn, "turn #{turn_id} was already answered" if shown.answered?
        end
        turn = turns.find { |t| !t.answered? } or raise ArgumentError, "interview is not accepting answers"
        raise StaleTurn, "turn #{turn_id} is no longer the current question" if turn_id && turn.id != turn_id.to_i

        item = Source.interview_for(interview.site).source_items.create!(
          external_id: "interview-turn-#{turn.id}",
          raw_content: text,
          metadata: { "turn_id" => turn.id, "question_kind" => turn.question_kind, "question_text" => turn.question_text }
        )
        turn.update!(answer_text: text, answered_at: Time.current, source_item: item)
        interview.increment!(:question_count)
        interview.update!(status: "ready") if interview.ready_to_generate?
        turn
      end
    end

    # Extraction runs after the answer is durably stored, outside its
    # transaction, so a model failure can never lose the answer.
    def answer_and_process!(text, turn_id: nil, processor: Processor.new(interview))
      turn = answer!(text, turn_id: turn_id)
      processor.process!(turn)   # claims the turn; a resubmit or a failed turn never extracts again
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
