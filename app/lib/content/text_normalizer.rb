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
  end
end
