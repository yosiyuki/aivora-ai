module Interviewing
  # Runs the Extraction Agent for one answered turn and applies the result.
  # An LLM failure never stops the interview: the turn is marked failed and
  # the runner falls back to fixed questions.
  class Processor
    def initialize(interview, agent: nil)
      @interview = interview
      @agent = agent || ExtractionAgent.new(interview)
    end

    # One LLM call per answered turn: the turn is claimed atomically first, and
    # a turn that is already processing, done or failed is left alone.
    # Routing, archetype resolution and the done mark share one transaction,
    # so a failure after the model answered leaves nothing half-written.
    def process!(turn)
      raise ArgumentError, "turn is not answered" unless turn.answered?
      return nil unless turn.claim_for_extraction!

      output = @agent.call(turn)
      @interview.transaction do
        Router.new(@interview).route!(turn, output)
        ArchetypeResolver.new(@interview).resolve!(output.dig("archetype", "candidates"))
        turn.update!(extraction_status: "done", extraction_error: nil)
      end
      output
    rescue Llm::Error, Router::Rejected, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, KeyError, StandardError => e
      Rails.logger.warn("interview extraction failed for turn #{turn.id}: #{e.class}: #{e.message}")
      turn.update!(extraction_status: "failed", extraction_error: "#{e.class}: #{e.message}".first(1000))
      @interview.update!(pending_question: nil)
      nil
    end
  end
end
