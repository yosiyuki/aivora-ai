module Interviewing
  # What a question looks like, whoever produces it. Examples are three
  # samples of differing length — a guide to granularity, never a menu.
  Question = Data.define(:text, :examples, :kind) do
    def initialize(text:, examples:, kind:)
      raise ArgumentError, "a question needs exactly three examples" unless examples.size == 3

      super
    end
  end
end
