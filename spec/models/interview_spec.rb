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

  it "cannot be completed before there is anything to generate from" do
    expect { interview.complete! }.to raise_error(Interview::NotFinishable)
    expect(interview.reload).not_to be_completed
    expect(site.reload.status).to eq("setup")
  end

  it "activates the site on completion once three answers exist" do
    runner = Interviewing::Runner.new(interview)
    3.times { |i| runner.answer!("答え #{i}") }
    interview.complete!
    expect(interview).to be_completed
    expect(site.reload.status).to eq("active")
    expect(interview.complete!).to eq(interview), "completing twice is a no-op"
  end

  it "enqueues the first page after commit, and not when the completion rolls back" do
    runner = Interviewing::Runner.new(interview)
    3.times { |i| runner.answer!("答え #{i}") }
    expect { interview.complete! }.to have_enqueued_job(Content::GenerateJob).with(site.id, "top")

    other = site.interviews.create!
    Interviewing::Runner.new(other).tap { |r| 3.times { |i| r.answer!("答え #{i}") } }
    expect do
      ActiveRecord::Base.transaction do
        other.complete!            # perform_later runs here...
        raise ActiveRecord::Rollback   # ...and the transaction is rolled back
      end
    end.not_to have_enqueued_job(Content::GenerateJob)
    expect(other.reload).not_to be_completed
  end
  it "has exactly one owner-trusted interview source per site, whatever state it is found in" do
    a = Source.interview_for(site)
    a.update_columns(trust_level: "external", enabled: false)
    b = Source.interview_for(site)
    expect(b).to eq(a)
    expect(b.reload).to have_attributes(trust_level: "owner", enabled: true)
    expect { site.sources.create!(source_type: "interview", name: "x") }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
