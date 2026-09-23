require "rails_helper"

RSpec.describe Verification::AnswerProcessor do
  let!(:site) { cafe_site }
  let(:user) { create_admin }
  let(:request) do
    site.verification_requests.create!(request_type: "initial", slot_key: "hours",
                                       question: "営業時間を教えてください。", priority: 290)
  end

  def answer!(text)
    request.record_answer!(text, person_id: VerificationEvent.person_id_for(user))
  end

  def stub_answer(value:, source_text:, answered: true, confidence: 0.9)
    Llm::Fake.respond(:extraction) do
      { "answered" => answered, "value" => value, "source_text" => source_text,
        "confidence" => confidence, "slot" => "hours" }
    end
  end

  it "records the answer as owner evidence and accepts the fact" do
    event = answer!("朝7時から夕方5時まで開けています")
    stub_answer(value: "7時-17時", source_text: "朝7時から夕方5時まで")

    described_class.new(event).process!

    fact = site.primary_entity.facts.for_slot("hours").sole
    expect(fact).to be_accepted
    expect(fact.slot_key).to eq("hours")
    expect(fact.value).to eq("7時-17時")
    expect(fact.evidence.sole.source_item.raw_content).to eq("朝7時から夕方5時まで開けています")
    expect(event.reload.extraction_status).to eq("done")
  end

  it "keeps the answer under its own source, not the interview's" do
    event = answer!("朝7時から夕方5時まで開けています")
    stub_answer(value: "7時-17時", source_text: "朝7時から夕方5時まで")

    described_class.new(event).process!

    item = event.reload.source_item
    expect(item.source.source_type).to eq("verification")
    expect(item.source).to be_owner
    expect(item.metadata).to include("verification_request_id" => request.id, "slot_key" => "hours")
  end

  it "leaves a fact unaccepted when the model did not quote the owner" do
    event = answer!("朝7時から夕方5時まで開けています")
    stub_answer(value: "24時間営業", source_text: "いつでも開いています")

    described_class.new(event).process!

    fact = site.primary_entity.facts.for_slot("hours").sole
    expect(fact).not_to be_accepted, "a span that is not in the answer is not the owner's word"
    expect(fact).not_to be_fills_slot
  end

  it "writes nothing when the owner did not actually answer" do
    event = answer!("あとで調べます")
    stub_answer(value: nil, source_text: nil, answered: false)

    described_class.new(event).process!

    expect(site.primary_entity.facts.for_slot("hours")).to be_empty
    expect(event.reload.extraction_status).to eq("done")
  end

  it "supersedes an existing fact instead of editing it" do
    old = site.primary_entity.facts.create!(attribute_key: "営業時間", slot_key: "hours",
                                            value_json: { "value" => "8時-16時" }, confidence: 0.8)
    old.accept!(evidence: owner_evidence(site, text: "8時から16時です"))

    event = answer!("朝7時から夕方5時まで開けています")
    stub_answer(value: "7時-17時", source_text: "朝7時から夕方5時まで")

    described_class.new(event).process!

    expect(old.reload.status).to eq("retired")
    expect(old.valid_until).to be_present, "the old value keeps its validity window"
    current = site.primary_entity.facts.current.for_slot("hours").sole
    expect(current.value).to eq("7時-17時")
    expect(current).to be_accepted
  end

  it "keeps the answer when the model fails, so it can be retried" do
    event = answer!("朝7時から夕方5時まで開けています")
    Llm::Fake.respond(:extraction) { raise Llm::RequestError.new("boom", retryable: true) }

    expect(described_class.new(event).process!).to be(false)
    expect(event.reload.extraction_status).to eq("failed")
    expect(event.notes).to eq("朝7時から夕方5時まで開けています"), "the owner's words survive"
  end

  it "extracts once per answer even if processed twice" do
    event = answer!("朝7時から夕方5時まで開けています")
    stub_answer(value: "7時-17時", source_text: "朝7時から夕方5時まで")

    expect(described_class.new(event).process!).to be(true)
    expect(described_class.new(event.reload).process!).to be(false), "already claimed"
    expect(site.primary_entity.facts.for_slot("hours").count).to eq(1)
  end
end
