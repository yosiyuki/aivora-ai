class Current < ActiveSupport::CurrentAttributes
  # llm_budgets memoises Llm::Budget per site for the length of one request or
  # job, so a page generation runs the monthly aggregate once rather than once
  # per LLM call.
  attribute :session, :site, :llm_budgets
  delegate :user, to: :session, allow_nil: true
end
