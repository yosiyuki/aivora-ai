module Content
  # Whitespace-insensitive, width-insensitive comparison used wherever code
  # checks whether the model's text really occurs in the user's text.
  module TextNormalizer
    module_function

    def normalize(text) = text.to_s.gsub(/[[:space:]]+/, "").unicode_normalize(:nfkc).downcase

    def include?(haystack, needle)
      n = normalize(needle)
      n.present? && normalize(haystack).include?(n)
    end

    # Also ignores punctuation: 「豆は、農園から」 and 「豆は農園から」 are the
    # same words. Used when matching prose against the owner's own words.
    PUNCT = /[[:punct:]、。，．・「」『』（）()〔〕【】]+/

    def loose(text) = normalize(text).gsub(PUNCT, "")

    def loose_include?(haystack, needle)
      n = loose(needle)
      n.present? && loose(haystack).include?(n)
    end

    DIGITS = /[0-9０-９]+/

    # Does `words` (the owner's own text) account for `statement`?
    #   - statement ⊆ words: yes (a fragment of what they said)
    #   - words ⊆ statement: only if words cover most of it and the statement
    #     adds no numbers of its own — otherwise the extra part is the model's.
    def covers?(words, statement, min_ratio: 0.8)
      w = loose(words)
      st = loose(statement)
      return false if w.blank? || st.blank?
      return true if w.include?(st)
      return false unless st.include?(w)
      return false if (st.scan(DIGITS) - w.scan(DIGITS)).any?

      w.length.to_f / st.length >= min_ratio
    end
  end
end
