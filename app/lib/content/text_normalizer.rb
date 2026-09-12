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
  end
end
