require "rails_helper"

RSpec.describe VerificationRequest, type: :model do
  let!(:site) { cafe_site }

  def build_request(**attrs)
    site.verification_requests.create!({ request_type: "initial", slot_key: "hours",
                                         question: "営業時間を教えてください。", priority: 290 }.merge(attrs))
  end

  it "records an answer and closes the question in one step" do
    request = build_request

    event = request.record_answer!("7時から17時まで", person_id: "user:1")

    expect(request.status).to eq("answered")
    expect(request.completed_at).to be_present
    expect(event.result).to eq("answered")
    expect(event.extraction_status).to eq("pending"), "knowledge comes later, in a job"
  end

  it "is never physically deleted" do
    request = build_request

    expect { request.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
  end

  it "asks the most important question first, oldest first within a rank" do
    old = build_request(slot_key: "hours", priority: 290)
    old.update!(created_at: 2.days.ago)
    same_rank = build_request(slot_key: "contact", priority: 290)
    lower = build_request(slot_key: "cadence", priority: 103)

    expect(described_class.open.by_priority.to_a).to eq([ old, same_rank, lower ])
  end

  it "rejects an unknown request type" do
    expect { build_request(request_type: "guess") }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
