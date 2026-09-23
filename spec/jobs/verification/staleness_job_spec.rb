require "rails_helper"

RSpec.describe Verification::StalenessJob do
  let!(:site) { cafe_site }

  def aged_fact(days, risk_level: "high", slot_key: "hours", value: "7時-17時")
    fact = site.primary_entity.facts.create!(attribute_key: "営業時間", slot_key: slot_key,
                                             value_json: { "value" => value },
                                             confidence: 0.9, risk_level: risk_level)
    fact.accept!(evidence: owner_evidence(site, text: "#{value} で開けています"))
    fact.update_columns(last_verified_at: days.days.ago)
    fact.reload
  end

  it "stops publishing a fact nobody has confirmed, and asks about it" do
    fact = aged_fact(120)

    described_class.perform_now

    expect(fact.reload.status).to eq("stale")
    expect(fact.valid_until).to be_nil, "unchecked is not the same as wrong"

    request = site.verification_requests.find_by(request_type: "recheck")
    expect(request.fact).to eq(fact)
    expect(request.slot_key).to eq("hours")
    # The owner is reminded what we hold, so confirming takes one word.
    expect(request.question).to include("営業時間")
    expect(request.question).to include("7時-17時")
    expect(request.question).not_to include("hours")
  end

  it "leaves a fact inside its window alone" do
    fact = aged_fact(30)

    described_class.perform_now

    expect(fact.reload.status).to eq("accepted")
    expect(site.verification_requests.where(request_type: "recheck")).to be_empty
  end

  it "does not ask about the same fact twice" do
    aged_fact(120)

    described_class.perform_now
    described_class.perform_now

    expect(site.verification_requests.where(request_type: "recheck").count).to eq(1)
  end

  it "keeps a stale fact out of the page's material" do
    aged_fact(120)

    described_class.perform_now
    pack = Content::KnowledgePack.for(site.reload, page_type: "top")

    expect(pack.facts.map(&:slot_key)).not_to include("hours")
    expect(pack.missing_slots.map(&:key)).to include("hours"), "it becomes a blank again"
  end

  it "calls no model, so an exhausted budget cannot stop observation" do
    aged_fact(120)
    LlmUsage.create!(site: site, operation_type: "drafting", model: "claude-opus-5",
                     estimated_cost: site.policy.monthly_budget + 1)
    Current.llm_budgets = nil

    expect { described_class.perform_now }.not_to change(LlmUsage, :count)
    expect(site.verification_requests.where(request_type: "recheck")).to be_present
  end

  it "still stops publishing a fact when raising the question is impossible" do
    fact = aged_fact(120, slot_key: "story")   # experiential slot: no recheck question is built
    allow(Verification::Requester).to receive(:new).and_raise(StandardError, "boom")

    expect { described_class.perform_now }.to raise_error(StandardError)
    expect(fact.reload.status).to eq("accepted"), "nothing was swept before the failure"
  end
end
