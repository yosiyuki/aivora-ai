require "rails_helper"

RSpec.describe VerificationEvent, type: :model do
  let!(:site) { cafe_site }
  let(:request) do
    site.verification_requests.create!(request_type: "initial", slot_key: "hours",
                                       question: "営業時間を教えてください。", priority: 290)
  end

  it "keeps the owner's words frozen while extraction state still moves" do
    event = request.record_answer!("7時から17時まで", person_id: "user:1")

    expect(event).to be_readonly, "the owner's answer is evidence and is never rewritten"

    event.update_extraction!(:done)

    expect(event.reload.extraction_status).to eq("done")
    expect(event.notes).to eq("7時から17時まで")
  end

  it "is claimed for extraction exactly once" do
    event = request.record_answer!("7時から17時まで", person_id: "user:1")

    expect(event.claim_for_extraction!).to be(true)
    expect(event.reload.claim_for_extraction!).to be(false)
  end

  it "names the answering person by channel and id" do
    user = create_admin

    expect(described_class.person_id_for(user)).to eq("user:#{user.id}")
  end

  it "is never physically deleted" do
    event = request.record_answer!("7時から17時まで", person_id: "user:1")

    expect { event.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
  end

  it "requires the answer text when the result is an answer" do
    expect {
      request.events.create!(person_id: "user:1", result: "answered", verified_at: Time.current)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
