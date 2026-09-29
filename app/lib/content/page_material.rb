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
      "topics"   => Rule.new(fact_slots: %w[name topic scope], experience_slots: %w[topic scope], questions: true, needs: %w[topic]),
      # Per-item pages: the subject is one knowledge row (:subject); the rest of
      # the pack is supporting material about the same entity.
      "article"  => Rule.new(fact_slots: ALL, experience_slots: :subject, questions: false, needs: [ :subject ]),
      "question" => Rule.new(fact_slots: ALL, experience_slots: ALL, questions: :subject, needs: [ :subject ])
    }.freeze

    # One page per row of this table (README §28 media: 記事 / knowledge_base: Q&A).
    # The subject is chosen mechanically — a row is a page — never by a model
    # deciding what deserves an article; that is the operation-phase planner.
    ITEM_PAGES = { "article" => "Experience", "question" => "Question" }.freeze

    # Pages generated from the interview's knowledge as a whole. Pages with no
    # Phase 1 source (news, categories) are not here on purpose (#64);
    # `articles` is built in code from the article pages (Content::Lister).
    LIST_PAGES = (RULES.keys - ITEM_PAGES.keys).freeze

    module_function

    def rule_for(page_type) = RULES[page_type.to_s]
    def generated?(page_type) = RULES.key?(page_type.to_s)
    def item_page?(page_type) = ITEM_PAGES.key?(page_type.to_s)
    def subject_class(page_type) = ITEM_PAGES.fetch(page_type.to_s).constantize
    def structure(site) = site.archetype_definitions.flat_map(&:page_structure).uniq

    # The archetype's structure, in its order, restricted to what can be built.
    # top is always first: an interview can finish before an archetype is
    # decided, and the site still needs a front page.
    def pages_for(site)
      ([ "top" ] + structure(site)).uniq.select { |t| LIST_PAGES.include?(t) }
    end

    # The item page types this site's structure calls for.
    def item_page_types_for(site) = structure(site).select { |t| item_page?(t) }
  end
end
