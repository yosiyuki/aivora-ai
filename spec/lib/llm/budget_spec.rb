require "rails_helper"

RSpec.describe Llm::Budget do
  let!(:site) { create_site }

  def spend(amount, created_at: Time.current, succeeded: true)
    LlmUsage.create!(site: site, operation_type: "drafting", model: "claude-opus-5",
                     estimated_cost: amount, succeeded: succeeded, created_at: created_at)
  end

  it "reads the limit from the site's policy, creating one with the default" do
    expect(site.site_policy).to be_nil

    expect(described_class.for(site).limit).to eq(BigDecimal("50.0"))
    expect(site.reload.site_policy.budget_action).to eq("degrade")
  end

  it "counts failed calls, which the provider still bills" do
    spend(10)
    spend(5, succeeded: false)

    expect(described_class.for(site).spent).to eq(BigDecimal("15"))
  end

  it "is not exceeded below the limit and is exceeded once the limit is reached" do
    site.policy.update!(monthly_budget: 20)
    spend(19)

    expect(described_class.for(site)).not_to be_exceeded

    Current.llm_budgets = nil
    spend(1)

    expect(described_class.for(site)).to be_exceeded
  end

  it "degrades rather than stopping, whatever budget_action says" do
    site.policy.update!(monthly_budget: 10, budget_action: "stop")
    spend(10)

    expect(described_class.for(site)).to be_degraded
  end

  it "ignores spend from another month" do
    site.policy.update!(monthly_budget: 10)
    spend(100, created_at: 2.months.ago)

    expect(described_class.for(site).spent).to eq(0)
    expect(described_class.for(site)).not_to be_exceeded
  end

  it "takes the month boundary from the site's timezone, not the server's" do
    site.update!(timezone: "Asia/Tokyo")
    # 23:30 UTC on the last day of September is already 08:30 on 1 October in
    # Tokyo, so this spend belongs to the site's next month, not this one.
    travel_to Time.utc(2026, 9, 30, 23, 30) do
      boundary = described_class.new(site).month_range
      expect(boundary.begin.in_time_zone("Asia/Tokyo").day).to eq(1)
      expect(boundary.begin.in_time_zone("Asia/Tokyo").month).to eq(10)
    end
  end

  it "runs the monthly aggregate once, not once per call" do
    spend(1)

    queries = 0
    callback = ->(_, _, _, _, payload) { queries += 1 if payload[:sql]&.include?("llm_usage") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      5.times { described_class.for(site).spent }
    end

    expect(queries).to eq(1), "generating one page must not re-aggregate per LLM call"
    expect(described_class.for(site)).to equal(described_class.for(site))
  end

  it "never blocks a call when there is no site yet" do
    budget = described_class.for(nil)

    expect(budget).not_to be_exceeded
    expect(budget).not_to be_degraded
    expect(budget.spent).to eq(0)
  end
end
