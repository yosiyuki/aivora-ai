require "rails_helper"

RSpec.describe Interviewing::ArchetypeResolver do
  let!(:site) { create_site }
  let(:interview) { site.interviews.create! }
  let(:resolver) { described_class.new(interview) }

  it "confirms the primary archetype at the threshold and adds strong secondaries" do
    site.goals.create!(name: "来てほしい", description: "近所の人に来てほしい")
    resolver.resolve!([ { "archetype" => "business", "confidence" => 0.9 }, { "archetype" => "media", "confidence" => 0.75 } ])

    expect(site.reload.primary_archetype).to eq("business")
    expect(site.site_archetypes.pluck(:archetype)).to contain_exactly("business", "media")
    expect(site.goals.sole.metric).to eq("visits_or_inquiries"), "metric comes from the definition"
    expect(interview.reload.archetype_hypothesis).to eq("business")
  end

  it "never overrides a primary once set" do
    resolver.resolve!([ { "archetype" => "business", "confidence" => 0.9 } ])
    resolver.resolve!([ { "archetype" => "portfolio", "confidence" => 0.95 } ])
    expect(site.reload.primary_archetype).to eq("business")
    expect(site.site_archetypes.pluck(:archetype)).to contain_exactly("business", "portfolio")
  end

  it "asks the clarifying question once after two low-confidence answers, then stops asking" do
    resolver.resolve!([ { "archetype" => "media", "confidence" => 0.4 } ])
    expect(interview.reload.pending_question).to be_nil
    resolver.resolve!([ { "archetype" => "media", "confidence" => 0.5 } ])
    expect(interview.reload.pending_question).to include("kind" => "clarify")
    expect(interview.pending_question["examples"].size).to eq(3)

    interview.update!(pending_question: nil)
    resolver.resolve!([ { "archetype" => "media", "confidence" => 0.5 } ])
    expect(interview.reload.pending_question).to be_nil, "only ever once"
    expect(site.reload.primary_archetype).to be_nil
  end

  it "marks the interview ready when the archetype arrives and its minimum slots are already filled" do
    interview.fill_slot!(:name, value: "山田")
    interview.fill_slot!(:what, value: "デザイナー")
    resolver.resolve!([ { "archetype" => "portfolio", "confidence" => 0.8 } ])
    expect(interview.reload.status).to eq("ready")
  end
  it "drops back to in_progress when a secondary archetype adds unfilled minimum slots" do
    interview.fill_slot!(:name, value: "山田")
    interview.fill_slot!(:what, value: "デザイナー")
    resolver.resolve!([ { "archetype" => "portfolio", "confidence" => 0.9 } ])
    expect(interview.reload.status).to eq("ready")

    resolver.resolve!([ { "archetype" => "portfolio", "confidence" => 0.9 }, { "archetype" => "media", "confidence" => 0.8 } ])
    expect(interview.reload.status).to eq("in_progress"), "media needs topic and audience"
    expect(interview.missing_minimum_slot_keys).to contain_exactly("topic", "audience")
  end

  it "clamps a confidence above 1 rather than trusting it" do
    resolver.resolve!([ { "archetype" => "business", "confidence" => 42 } ])
    expect(interview.reload.archetype_confidence).to eq(1.0)
  end
end
