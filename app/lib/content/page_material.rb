module Content
  # Which knowledge each page type is built from, fixed in code (README §28:
  # structure is the product's, never the model's). The LLM writes from what
  # this table hands it; it does not choose what a page is about.
  #
  # A page whose material is absent is not drafted at all — no model call,
  # no version — so fanning out over an archetype's structure costs nothing
  # for the pages the site cannot fill yet. Answers to verification requests
  # make them possible later (ProcessAnswersJob retries unpublished pages).
  module PageMaterial
    ALL = :all

    Rule = Data.define(:fact_slots, :experience_slots, :questions, :needs) do
      def facts_all? = fact_slots == ALL
      def experiences_all? = experience_slots == ALL
    end

    # needs: any of these slots present (as a fact or a slot-keyed experience)
    # makes the page worth drafting; :questions means at least one question.
    RULES = {
      "top"      => Rule.new(fact_slots: ALL, experience_slots: ALL, questions: false, needs: [ :any ]),
      "services" => Rule.new(fact_slots: %w[name offerings what contact], experience_slots: %w[what offerings], questions: false, needs: %w[offerings what]),
      "faq"      => Rule.new(fact_slots: ALL, experience_slots: ALL, questions: true, needs: [ :questions ]),
      "profile"  => Rule.new(fact_slots: %w[name what story contact location], experience_slots: %w[what story], questions: false, needs: %w[what story]),
      "works"    => Rule.new(fact_slots: %w[name works], experience_slots: %w[works], questions: false, needs: %w[works]),
      "topics"   => Rule.new(fact_slots: %w[name topic scope], experience_slots: %w[topic scope], questions: true, needs: %w[topic])
    }.freeze

    # Pages generated from the interview's knowledge alone. Per-item pages
    # (article / question) and pages with no Phase 1 source (news, articles,
    # categories) are not here on purpose (#63, #64).
    LIST_PAGES = RULES.keys.freeze

    module_function

    def rule_for(page_type) = RULES[page_type.to_s]
    def generated?(page_type) = RULES.key?(page_type.to_s)

    # The archetype's structure, in its order, restricted to what can be built.
    # top is always first: an interview can finish before an archetype is
    # decided, and the site still needs a front page.
    def pages_for(site)
      ([ "top" ] + site.archetype_definitions.flat_map(&:page_structure)).uniq.select { |t| generated?(t) }
    end
  end
end
