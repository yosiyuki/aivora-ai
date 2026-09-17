require "rails_helper"

RSpec.describe SitePolicy, type: :model do
  let!(:site) { create_site }

  it "defaults to a conservative budget that degrades rather than stops" do
    policy = site.policy

    expect(policy.monthly_budget).to eq(BigDecimal("50.0"))
    expect(policy.budget_action).to eq("degrade")
  end

  it "creates the row once and returns the same one afterwards" do
    policy = site.policy

    expect(site.reload.policy).to eq(policy)
    expect(described_class.count).to eq(1)
  end

  it "rejects an unknown budget action and a budget of zero" do
    policy = site.policy

    policy.budget_action = "pause"
    expect(policy).not_to be_valid

    policy.budget_action = "stop"
    policy.monthly_budget = 0
    expect(policy).not_to be_valid
  end

  it "degrades in phase 1 even when the action says stop" do
    expect(site.policy.tap { |p| p.update!(budget_action: "stop") }).to be_degrade_only
  end
end
