module Content
  # What the drafter may write from, assembled in code: accepted facts, the
  # owner's experiences, the goals (as intent, never as fact) and the slots
  # the archetype needs. The model sees short refs (F12 / E3), never ids.
  class KnowledgePack
    FactRef = Data.define(:ref, :id, :attribute_key, :value, :entity_name)
    ExperienceRef = Data.define(:ref, :id, :summary, :body)
    SlotRef = Data.define(:key, :label, :kind, :level, :filled)

    LIMITS = { facts: 200, experiences: 50, body_chars: 12_000 }.freeze

    attr_reader :site, :page_type, :archetype, :facts, :experiences, :goals, :slots, :entity, :truncated

    def self.for(site, page_type:) = new(site, page_type)

    def initialize(site, page_type)
      @site = site
      @page_type = page_type.to_s
      @archetype = site.primary_archetype_definition
      @entity = site.primary_entity
      @truncated = false
      @facts = build_facts
      @experiences = build_experiences
      @goals = site.goals.where(status: %w[proposed active]).order(:created_at).map(&:description)
      @slots = build_slots
    end

    def truncated? = @truncated
    def fact_by_ref(ref) = @facts_by_ref[ref.to_s]
    def experience_by_ref(ref) = @experiences_by_ref[ref.to_s]
    def refs = @facts_by_ref.keys + @experiences_by_ref.keys
    def slot_keys = slots.map(&:key)
    def missing_slots = slots.reject(&:filled)
    def slot_label(key) = slots.find { |s| s.key == key.to_s }&.label

    def to_prompt
      lines = []
      lines << "## 主語"
      lines << (entity ? "#{entity.canonical_name}（#{entity.entity_type}）" : site.name)
      lines << "\n## 事実（F）"
      lines.concat(facts.map { |f| "#{f.ref}: #{f.attribute_key} = #{f.value}" }.presence || [ "（まだありません）" ])
      lines << "\n## 体験・こだわり（E）"
      lines.concat(experiences.flat_map { |e| [ "#{e.ref}: #{e.summary}", "  本人の言葉: 「#{e.body}」" ] }.presence || [ "（まだありません）" ])
      lines << "\n## 目的（参考。事実ではない）"
      lines.concat(goals.map { |g| "- #{g}" }.presence || [ "（未設定）" ])
      lines << "\n## 未充足のスロット（無い事実はこのキーで [[slot:キー]] と書く）"
      lines.concat(missing_slots.map { |s| "- #{s.key}=#{s.label}" }.presence || [ "（すべて揃っています）" ])
      lines.join("\n")
    end

    private

    def build_facts
      scope = ::Fact.current.where(site: site).includes(:entity).order(:id)
      rows = scope.limit(LIMITS[:facts]).to_a
      @truncated = true if scope.count > rows.size
      @facts_by_ref = {}
      rows.each_with_index.map do |fact, i|
        FactRef.new(ref: "F#{i + 1}", id: fact.id, attribute_key: fact.attribute_key, value: fact.value.to_s,
                    entity_name: fact.entity.canonical_name).tap { |r| @facts_by_ref[r.ref] = r }
      end
    end

    def build_experiences
      rows = site.experiences.order(:created_at).limit(LIMITS[:experiences]).to_a
      @truncated = true if site.experiences.count > rows.size
      @experiences_by_ref = {}
      budget = LIMITS[:body_chars]
      rows.each_with_index.filter_map do |exp, i|
        body = exp.body.presence || exp.summary
        if budget - body.length < 0
          @truncated = true
          next
        end
        budget -= body.length
        ExperienceRef.new(ref: "E#{i + 1}", id: exp.id, summary: exp.summary, body: body).tap { |r| @experiences_by_ref[r.ref] = r }
      end
    end

    def build_slots
      filled_keys = (site.current_interview&.filled_slot_keys || []) + facts.map(&:attribute_key)
      site.required_slots.map do |s|
        SlotRef.new(key: s.key, label: s.label, kind: s.kind, level: s.level, filled: filled_keys.include?(s.key))
      end
    end
  end
end
