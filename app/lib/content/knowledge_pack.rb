module Content
  # What the drafter may write from, assembled in code: accepted facts, the
  # owner's experiences, the goals (as intent, never as fact) and the slots
  # the archetype needs. The model sees short refs (F12 / E3), never ids.
  class KnowledgePack
    FactRef = Data.define(:ref, :id, :attribute_key, :slot_key, :value, :entity_name)
    ExperienceRef = Data.define(:ref, :id, :summary, :body, :slot_key)
    QuestionRef = Data.define(:ref, :id, :text)
    SlotRef = Data.define(:key, :label, :kind, :level, :filled)

    LIMITS = { facts: 200, experiences: 50, questions: 30, body_chars: 12_000 }.freeze

    attr_reader :site, :page_type, :archetype, :facts, :experiences, :questions, :goals, :slots, :entity, :truncated, :rule

    def self.for(site, page_type:) = new(site, page_type)

    def initialize(site, page_type)
      @site = site
      @page_type = page_type.to_s
      # What this page is built from is decided by the table, not the model.
      @rule = PageMaterial.rule_for(@page_type) || PageMaterial.rule_for("top")
      @archetype = site.primary_archetype_definition
      @entity = site.primary_entity
      @truncated = false
      @facts = build_facts
      @experiences = build_experiences
      @questions = build_questions
      @goals = site.goals.where(status: %w[proposed active]).order(:created_at).map(&:description)
      @slots = build_slots
    end

    def truncated? = @truncated
    def fact_by_ref(ref) = @facts_by_ref[ref.to_s]
    def experience_by_ref(ref) = @experiences_by_ref[ref.to_s]
    def question_by_ref(ref) = @questions_by_ref[ref.to_s]
    def refs = @facts_by_ref.keys + @experiences_by_ref.keys + @questions_by_ref.keys

    # Whether there is anything to write this page from. Decided before either
    # model call: a page without material is not drafted, it waits.
    def sufficient?
      return false unless PageMaterial.generated?(page_type)

      rule.needs.any? do |need|
        case need
        when :any then facts.any? || experiences.any?
        when :questions then questions.any?
        else facts.any? { |f| f.slot_key == need } || experiences.any? { |e| e.slot_key == need }
        end
      end
    end
    def slot_keys = slots.map(&:key)
    def missing_slots = slots.reject(&:filled)
    # Only a verifiable fact can be left as a placeholder; experiences are
    # either in the pack or simply not written.
    def placeholder_slots = missing_slots.select { |s| s.kind == "verifiable" }
    def slot_label(key) = slots.find { |s| s.key == key.to_s }&.label

    def to_prompt
      lines = []
      lines << "## 主語"
      lines << (entity ? "#{entity.canonical_name}（#{entity.entity_type}）" : site.name)
      lines << "\n## 事実（F）"
      lines.concat(facts.map { |f| "#{f.ref}: #{f.entity_name} の #{slot_label(f.slot_key) || f.attribute_key} = #{f.value}" }.presence || [ "（まだありません）" ])
      lines << "\n## 体験・こだわり（E）"
      lines.concat(experiences.flat_map { |e| [ "#{e.ref}: #{e.summary}", "  本人の言葉: 「#{e.body}」" ] }.presence || [ "（まだありません）" ])
      if rule.questions
        lines << "\n## よく聞かれること（Q）— 質問文をそのまま見出しにしてよい。答えは F・E だけで書く"
        lines.concat(questions.map { |q| "#{q.ref}: #{q.text}" }.presence || [ "（まだありません）" ])
      end
      lines << "\n## 目的（参考。事実ではない）"
      lines.concat(goals.map { |g| "- #{g}" }.presence || [ "（未設定）" ])
      lines << "\n## 手元に無い事実（書きたければこのキーで [[slot:キー]] と書く。それ以外のキーは使わない）"
      lines.concat(placeholder_slots.map { |s| "- #{s.key}=#{s.label}" }.presence || [ "（すべて揃っています）" ])
      lines.join("\n")
    end

    private

    # Facts about the page's subject only (the primary entity when there is
    # one), ordered by slot weight so truncation drops the least important.
    def build_facts
      scope = ::Fact.current.where(site: site).includes(:entity)
      scope = scope.where(entity_id: entity.id) if entity
      scope = scope.where(slot_key: rule.fact_slots) unless rule.facts_all?
      weights = site.required_slots.to_h { |s| [ s.key, s.weight ] }
      ordered = scope.to_a.sort_by { |f| [ -(weights[f.slot_key] || 0), -f.last_verified_at.to_i, f.id ] }
      rows = ordered.first(LIMITS[:facts])
      @truncated = true if ordered.size > rows.size
      @facts_by_ref = {}
      rows.each_with_index.map do |fact, i|
        FactRef.new(ref: "F#{i + 1}", id: fact.id, attribute_key: fact.attribute_key, slot_key: fact.slot_key,
                    value: fact.value.to_s, entity_name: fact.entity.canonical_name).tap { |r| @facts_by_ref[r.ref] = r }
      end
    end

    def build_experiences
      scope = site.experiences.order(:created_at)
      scope = scope.where(entity_id: [ entity.id, nil ]) if entity   # the subject's, or unattributed owner words
      scope = scope.where(slot_key: rule.experience_slots) unless rule.experiences_all?
      rows = scope.limit(LIMITS[:experiences]).to_a
      @truncated = true if scope.count > rows.size
      @experiences_by_ref = {}
      budget = LIMITS[:body_chars]
      rows.each_with_index.filter_map do |exp, i|
        body = exp.body.presence || exp.summary
        if budget - body.length < 0
          @truncated = true
          next
        end
        budget -= body.length
        ExperienceRef.new(ref: "E#{i + 1}", id: exp.id, summary: exp.summary, body: body, slot_key: exp.slot_key)
                     .tap { |r| @experiences_by_ref[r.ref] = r }
      end
    end

    # What visitors ask (README §9). Only pages whose rule asks for them see
    # any; the reference is the question's own words, which is what a FAQ
    # heading has to match.
    def build_questions
      @questions_by_ref = {}
      return [] unless rule.questions

      scope = site.questions.order(frequency: :desc, first_seen_at: :asc)
      scope = scope.where(entity_id: [ entity.id, nil ]) if entity
      scope.limit(LIMITS[:questions]).to_a.each_with_index.map do |q, i|
        QuestionRef.new(ref: "Q#{i + 1}", id: q.id, text: q.text).tap { |r| @questions_by_ref[r.ref] = r }
      end
    end

    def build_slots
      # attribute_key is free text from the extraction and never matched a slot
      # key; slot_key is the vocabulary that does.
      filled_keys = (site.current_interview&.filled_slot_keys || []) + facts.filter_map(&:slot_key)
      filled_keys << "name" if entity   # the subject's name is known once there is a primary entity
      site.required_slots.map do |s|
        SlotRef.new(key: s.key, label: s.label, kind: s.kind, level: s.level, filled: filled_keys.include?(s.key))
      end
    end
  end
end
