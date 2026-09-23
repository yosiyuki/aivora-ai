require "rails_helper"

RSpec.describe Verification::ProcessAnswersJob do
  let!(:site) { cafe_site }
  let(:user) { create_admin }

  def request_for(slot_key)
    site.verification_requests.create!(request_type: "initial", slot_key: slot_key,
                                       question: "教えてください。", priority: 290)
  end

  def answer!(request, text)
    request.record_answer!(text, person_id: VerificationEvent.person_id_for(user))
  end

  def stub_answer(value:, source_text:)
    Llm::Fake.respond(:extraction) { { "answered" => true, "value" => value, "source_text" => source_text, "confidence" => 0.9 } }
  end

  it "picks up every answer waiting for extraction" do
    answer!(request_for("hours"), "朝7時から夕方5時まで開けています")
    stub_answer(value: "7時-17時", source_text: "朝7時から夕方5時まで")

    described_class.perform_now

    expect(site.primary_entity.facts.for_slot("hours").sole).to be_accepted
    expect(VerificationEvent.pending_extraction).to be_empty
  end

  it "rebuilds only the pages whose blank the answer filled" do
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    other = site.content_items.create!(archetype_page_type: "faq", url: "/faq")
    other.publish!(other.append_version!(body: "よくある質問", title: "よくある質問").tap { |v| v.decide!(:passed) })

    request = site.verification_requests.find_by(slot_key: "hours")
    answer!(request, "朝7時から夕方5時まで開けています")
    stub_answer(value: "7時-17時", source_text: "朝7時から夕方5時まで")

    expect { described_class.perform_now }
      .to have_enqueued_job(Content::GenerateJob).with(site.id, "top").exactly(:once)
    expect(Content::GenerateJob).not_to have_been_enqueued.with(site.id, "faq")
  end

  it "enqueues nothing when no page carried that blank" do
    answer!(request_for("contact"), "メールは info@example.com です")
    stub_answer(value: "info@example.com", source_text: "info@example.com")

    expect { described_class.perform_now }.not_to have_enqueued_job(Content::GenerateJob)
  end

  it "leaves a failed extraction retryable and does not rebuild" do
    answer!(request_for("hours"), "朝7時から夕方5時まで開けています")
    Llm::Fake.respond(:extraction) { raise Llm::RequestError.new("boom", retryable: true) }

    expect { described_class.perform_now }.not_to have_enqueued_job(Content::GenerateJob)
    expect(VerificationEvent.sole.extraction_status).to eq("failed")
  end
end
