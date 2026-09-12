module Content
  # Decides, in code, which claims are backed by the pack; removes the
  # sentences that are not and leaves [[slot:key]] in their place. No LLM.
  class Grounder
    Result = Data.define(:body, :claims, :blanks, :status, :notes)
    Sentence = Struct.new(:text, :kind, :para, :remove, :slot_key)

    SLOT = ContentVersion::BLANK_PATTERN
    SENTENCE_SPLIT = /(?<=[。！？!?])/

    def initialize(pack)
      @pack = pack
    end

    def ground(body:, claims:)
      notes = []
      body, placeholder_blanks = normalize_placeholders(body)   # the drafter's own [[slot:*]]
      sentences = split(body)
      decisions = claims.map { |c| decide(c) }
      claim_rows = []

      decisions.each do |d|
        idx = locate(sentences, d[:statement])
        unless idx
          notes << "claim not found in body: #{d[:statement].first(40)}"
          next
        end
        if d[:verdict] == :blank || d[:verdict] == :excised
          sentences[idx].remove = true
          sentences[idx].slot_key = d[:slot_key] if d[:verdict] == :blank && d[:slot_key]
        end
        claim_rows << row_for(d, body)
      end

      structural_failure = sentences.any? { |s| s.remove && s.kind == :heading }
      new_body = rebuild(sentences)
      blanks = claim_rows.select { |r| r[:review_status] == "blank" }.map { |r| { "slot_key" => r[:slot_key], "statement" => r[:statement] } }
      blanks.concat(placeholder_blanks)

      status = if structural_failure then :failed
      elsif new_body.blank? then :failed
      else :passed
      end
      notes << "heading contained an ungrounded claim" if structural_failure
      Result.new(body: new_body, claims: claim_rows, blanks: blanks.uniq, status: status, notes: notes)
    end

    private

    # --- decisions --------------------------------------------------------

    def decide(claim)
      statement = claim["statement"].to_s
      kind = claim["kind"].to_s
      ref = claim.dig("support", "ref").to_s
      confidence = claim["confidence"].to_f.clamp(0.0, 1.0)
      base = { statement: statement, kind: kind, confidence: confidence, slot_key: nil, knowledge: nil }

      case kind
      when "verifiable"
        fact = @pack.fact_by_ref(ref)
        if fact && TextNormalizer.include?(statement, fact.value)
          base.merge(verdict: :grounded, knowledge: [ "Fact", fact.id ])
        else
          base.merge(verdict: :blank, slot_key: slot_key_for(claim, fact))
        end
      when "experiential"
        exp = @pack.experience_by_ref(ref)
        exp ? base.merge(verdict: :grounded, knowledge: [ "Experience", exp.id ]) : base.merge(verdict: :excised)
      else
        base.merge(kind: "general", verdict: :general)
      end
    end

    def slot_key_for(claim, fact)
      key = claim["slot_key"].presence || fact&.attribute_key
      @pack.slot_keys.include?(key.to_s) ? key.to_s : "unknown"
    end

    def row_for(d, body)
      start = body.index(d[:statement])
      {
        statement: d[:statement], claim_kind: d[:kind], confidence: d[:confidence],
        knowledge_type: d[:knowledge]&.first, knowledge_id: d[:knowledge]&.last,
        grounded: %i[grounded general].include?(d[:verdict]),
        review_status: d[:verdict].to_s, slot_key: d[:slot_key],
        start_offset: start, end_offset: start && start + d[:statement].length
      }
    end

    # --- text -------------------------------------------------------------

    def split(body)
      body.to_s.split(/\n/, -1).each_with_index.flat_map do |line, para|
        stripped = line.strip
        next [ Sentence.new(line, :blank_line, para) ] if stripped.empty?
        next [ Sentence.new(line, :heading, para) ] if stripped.start_with?("#")
        next [ Sentence.new(line, :list, para) ] if stripped.match?(/\A([-*+]|\d+\.)\s/)

        line.split(SENTENCE_SPLIT).map { |s| Sentence.new(s, :text, para) }
      end
    end

    def locate(sentences, statement)
      sentences.each_index.find do |i|
        s = sentences[i]
        next false if s.kind == :blank_line
        TextNormalizer.include?(s.text, statement) || (s.kind == :text && TextNormalizer.include?(statement, s.text))
      end
    end

    def rebuild(sentences)
      sentences.group_by(&:para).sort.map do |_, group|
        parts = group.map do |s|
          next s.text unless s.remove
          s.slot_key ? "[[slot:#{s.slot_key}]]" : ""
        end
        line = parts.join
        # collapse a slot repeated within one paragraph
        seen = []
        line.gsub(SLOT) { |m| seen.include?(m) ? "" : (seen << m; m) }.gsub(/[ \t]{2,}/, " ").rstrip
      end.join("\n").gsub(/\n{3,}/, "\n\n").strip
    end

    # Drafter-written placeholders: unknown keys become "unknown"; each key is a blank.
    def normalize_placeholders(body)
      blanks = []
      normalized = body.gsub(SLOT) do
        key = @pack.slot_keys.include?(Regexp.last_match(1)) ? Regexp.last_match(1) : "unknown"
        blanks << { "slot_key" => key, "statement" => nil }
        "[[slot:#{key}]]"
      end
      [ normalized, blanks.uniq ]
    end
  end
end
