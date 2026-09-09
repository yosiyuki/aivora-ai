module Interviewing
  # Turns the model's archetype candidates into a decision. Thresholds and the
  # single clarifying question are code (README §27.4); the model only ranks.
  class ArchetypeResolver
    CONFIRM = 0.7
    SECONDARY = 0.7
    LOW_STREAK_BEFORE_CLARIFY = 2

    CLARIFY = Question.new(kind: "clarify", text: "このサイトを見た人に、どうなってほしいですか？",
                           examples: [ "お店に来てほしい",
                                       "内容を読んで、知ってほしい",
                                       "自分の仕事を知ってもらって、いつか声をかけてもらえたら嬉しい" ])

    def initialize(interview)
      @interview = interview
      @site = interview.site
    end

    def resolve!(candidates)
      ranked = Array(candidates).select { |c| ArchetypeDefinition.exists?(c["archetype"]) }
                                .sort_by { |c| -c["confidence"].to_f }
      top = ranked.first
      @interview.update!(archetype_hypothesis: top&.dig("archetype"), archetype_confidence: top&.dig("confidence")&.to_f)
      return handle_low_confidence unless top && top["confidence"].to_f >= CONFIRM

      @interview.update!(low_confidence_streak: 0)
      unless @site.primary_archetype.present?
        @site.add_archetype(top["archetype"], primary: true)
        adopt_metric!(ArchetypeDefinition.find(top["archetype"]))
      end
      # Archetypes compose: any other strong candidate is added, never swapped in.
      ranked.reject { |c| c["archetype"] == @site.reload.primary_archetype }
            .select { |c| c["confidence"].to_f >= SECONDARY }
            .each { |c| @site.add_archetype(c["archetype"]) }
      @interview.update!(status: "ready") if @interview.in_progress? && @interview.ready_to_generate?
    end

    private

    def handle_low_confidence
      return if @site.primary_archetype.present?

      streak = @interview.low_confidence_streak + 1
      @interview.update!(low_confidence_streak: streak)
      return unless streak >= LOW_STREAK_BEFORE_CLARIFY && !@interview.clarification_asked

      @interview.update!(clarification_asked: true,
                         pending_question: { "text" => CLARIFY.text, "examples" => CLARIFY.examples, "targets_slot" => nil, "kind" => "clarify" })
    end

    def adopt_metric!(definition)
      @site.goals.where(archetype: nil).find_each { |g| g.adopt_archetype!(definition) }
    end
  end
end
