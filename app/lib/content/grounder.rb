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

    # Fail-closed: every heading, list item and sentence must be accounted for
    # by a grounded/general claim, a placeholder line, or a structural heading.
    # Anything the extractor did not cover is removed; an uncovered or
    # ungrounded heading fails the version.
    def ground(body:, claims:)
      notes = []
      body, placeholder_blanks, placeholder_failure = normalize_placeholders(body)
      sentences = split(body)
      claim_rows = []
      covered = Hash.new { |h, k| h[k] = [] }

      claims.map { |c| decide(c) }.each do |d|
        idx = locate(sentences, d[:statement])
        unless idx
          notes << "claim not found in body: #{d[:statement].first(40)}"
          next
        end
        d = d.merge(kind: "general", verdict: :general, knowledge: nil, slot_key: nil) if sentences[idx].kind == :heading && structural_heading?(sentences[idx].text)
        covered[idx] << d[:verdict]
        if %i[blank excised].include?(d[:verdict])
          sentences[idx].remove = true
          sentences[idx].slot_key = d[:slot_key] if d[:verdict] == :blank && d[:slot_key]
        end
        claim_rows << row_for(d, body)
      end

      sentences.each_with_index do |s, i|
        next if s.kind == :blank_line || covered.key?(i) || placeholder_line?(s)
        next if s.kind == :heading && structural_heading?(s.text)

        s.remove = true
        notes << "uncovered #{s.kind} removed: #{s.text.strip.first(40)}"
      end

      structural_failure = placeholder_failure || sentences.any? { |s| s.remove && s.kind == :heading }
      drop_empty_sections!(sentences)
      new_body = rebuild(sentences)
      blanks = claim_rows.select { |r| r[:review_status] == "blank" }.map { |r| { "slot_key" => r[:slot_key], "statement" => r[:statement] } }
      blanks.concat(placeholder_blanks)

      status = structural_failure || new_body.blank? ? :failed : :passed
      notes << "heading contained an ungrounded or uncovered claim" if structural_failure
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

      # "general" is only trusted for text with nothing site-specific in it;
      # anything with numbers or shop-specific words is judged as verifiable.
      if kind == "general" && specific?(statement)
        kind = "verifiable"
        base[:kind] = kind
      end
      return base.merge(kind: "general", verdict: :general) if kind == "general"

      # A fact reference counts only if the fact's value is in the sentence and
      # the sentence adds no numbers the pack does not know.
      fact = @pack.fact_by_ref(ref)
      if kind == "verifiable" && fact && fact_supports?(fact, statement)
        return base.merge(verdict: :grounded, knowledge: [ "Fact", fact.id ])
      end

      # The owner's own words ground a sentence whatever the model called it,
      # but a reference alone never does: the text has to match.
      exp = experience_covering(statement, preferred: @pack.experience_by_ref(ref))
      return base.merge(kind: "experiential", verdict: :grounded, knowledge: [ "Experience", exp.id ]) if exp

      if kind == "verifiable" && (key = slot_key_for(claim, fact))
        base.merge(verdict: :blank, slot_key: key)
      else
        base.merge(verdict: :excised)   # nothing to say here: drop the sentence, leave no filler
      end
    end

    SPECIFIC = /[0-9０-９]|円|時から|時まで|分間|km|メートル|価格|料金|住所|駅|徒歩|No\.?\s?1|一番|最高|唯一|世界一|日本一/i

    def specific?(statement)
      statement.match?(SPECIFIC) || (@pack.entity && TextNormalizer.loose_include?(statement, @pack.entity.canonical_name))
    end

    # The fact's value must occur; every number in the sentence must come from
    # some fact in the pack; short or numeric values also need their slot label.
    def fact_supports?(fact, statement)
      return false unless TextNormalizer.include?(statement, fact.value)

      known_digits = @pack.facts.flat_map { |f| TextNormalizer.loose(f.value).scan(TextNormalizer::DIGITS) }
      return false if (TextNormalizer.loose(statement).scan(TextNormalizer::DIGITS) - known_digits).any?

      value = TextNormalizer.loose(fact.value)
      return true if value.length >= 2 && !value.match?(/\A[0-9]+\z/)

      label = @pack.slot_label(fact.attribute_key)
      label.present? && TextNormalizer.loose_include?(statement, label)
    end

    def experience_covering(statement, preferred: nil)
      candidates = [ preferred, *@pack.experiences ].compact.uniq
      candidates.find { |e| TextNormalizer.covers?(e.body, statement) }
    end

    # A blank needs a real slot; without one the sentence is simply removed.
    def slot_key_for(claim, fact)
      key = claim["slot_key"].presence || fact&.attribute_key
      @pack.slot_keys.include?(key.to_s) ? key.to_s : nil
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
        next [ Sentence.new(line, :blank_line, para, true) ] if stripped.match?(/\A([-*_]\s*){3,}\z/)   # hr: decorative, dropped
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

    # A short heading with no numbers is a label ("どんなお店か"), not a claim.
    def structural_heading?(text)
      t = text.sub(/\A\s*#+\s*/, "").strip
      t.length <= 20 && !t.match?(SPECIFIC) && !t.match?(SLOT)
    end

    # A sentence built around a known placeholder is a blank by construction;
    # it stays as long as the framing text carries nothing specific of its own.
    def placeholder_line?(sentence)
      return false unless sentence.text.match?(SLOT)

      framing = sentence.text.gsub(SLOT, "")
      !framing.match?(SPECIFIC)
    end

    # A heading whose whole section was removed is dropped too (not a failure:
    # nothing false remains, just nothing to say under that heading).
    def drop_empty_sections!(sentences)
      sentences.each_with_index do |s, i|
        next unless s.kind == :heading && !s.remove

        level = s.text[/\A\s*(#+)/, 1].to_s.length
        rest = sentences.drop(i + 1)
        section = rest.take_while { |t| !(t.kind == :heading && t.text[/\A\s*(#+)/, 1].to_s.length <= level) }
        s.remove = true if section.none? { |t| t.kind != :blank_line && !t.remove }
      end
    end

    # A slot that already appears earlier in the body is not repeated: one
    # blank per missing fact is enough for the reader and for verification.
    def rebuild(sentences)
      seen = []
      sentences.group_by(&:para).sort.map do |_, group|
        parts = group.map do |s|
          next s.text unless s.remove
          s.slot_key ? "[[slot:#{s.slot_key}]]" : ""
        end
        parts.join.gsub(SLOT) { |m| seen.include?(m) ? "" : (seen << m; m) }.gsub(/[ \t]{2,}/, " ").rstrip
      end.join("\n").gsub(/\n{3,}/, "\n\n").strip
    end

    # Drafter-written placeholders: known slot keys are blanks and may appear
    # only in body text. A line carrying an unknown key is removed whole; any
    # placeholder in a heading fails the version.
    def normalize_placeholders(body)
      blanks = []
      failure = false
      lines = body.to_s.lines.filter_map do |line|
        keys = line.scan(SLOT).flatten
        next line if keys.empty?

        if line.strip.start_with?("#")
          failure = true
          next line
        end
        next nil if keys.any? { |k| !@pack.slot_keys.include?(k) }   # unknown key: drop the line

        keys.uniq.each { |k| blanks << { "slot_key" => k, "statement" => nil } }
        line
      end
      [ lines.join, blanks.uniq, failure ]
    end
  end
end
