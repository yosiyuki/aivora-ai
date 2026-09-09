require "rails_helper"

RSpec.describe Interview, type: :model do
  let!(:site) { create_site }
  let(:interview) { site.interviews.create! }

  it "is never ready before an archetype gives it minimum slots" do
    expect(interview.minimum_slot_keys).to be_empty
    expect(interview).not_to be_ready_to_generate
  end

  it "becomes ready when every minimum slot of the site's archetypes is filled, by code not by the model" do
    site.add_archetype(:business, primary: true)
    interview.fill_slot!(:name, value: "渋谷のカフェ")
    interview.fill_slot!(:what, value: "自家焙煎のコーヒー")
    expect(interview.missing_minimum_slot_keys).to eq([ "location" ])
    expect(interview).not_to be_ready_to_generate

    interview.fill_slot!(:location, value: "渋谷", confidence: 0.9)
    expect(interview).to be_ready_to_generate
    expect(interview.slot_state.dig("location", "confidence")).to eq(0.9)
  end

  it "caps at ten questions" do
    interview.update!(question_count: 9)
    expect(interview).not_to be_capped
    interview.increment!(:question_count)
    expect(interview).to be_capped
  end

  it "activates the site on completion" do
    interview.complete!
    expect(interview).to be_completed
    expect(site.reload.status).to eq("active")
  end
end
