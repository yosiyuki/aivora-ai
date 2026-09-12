module Llm
  # What an adapter returns: the text and the accounting. Adapters never
  # interpret the text; Llm::Client does.
  Result = Data.define(:text, :model, :stop_reason, :usage, :stop_details) do
    def initialize(text:, model:, stop_reason:, usage:, stop_details: nil)
      super
    end
  end
end
