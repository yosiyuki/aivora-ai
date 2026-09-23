require "rails_helper"

RSpec.describe Verification::Requester do
  let!(:site) { cafe_site }

  def generate!
    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")
    site.reload.top_page.latest_version
  end

  it "asks about the blank the page was left with" do
    version = generate!

    request = site.verification_requests.find_by(slot_key: "hours")

    expect(request).to be_present
    expect(request.request_type).to eq("initial")
    expect(request.question).to include("営業時間"), "the slot's label"
    expect(request.question).not_to include("hours"), "never the key"
  end

  it "also asks about slots no page has mentioned yet" do
    generate!

    keys = site.verification_requests.open.pluck(:slot_key)

    expect(keys).to include("contact"), "a standard slot the interview never asks for"
    expect(keys).not_to include("location"), "already known from the interview"
  end

  it "asks minimum slots before standard ones, and weight breaks the tie" do
    site.content_items.create!(archetype_page_type: "faq", url: "/faq")
    described_class.new(site).issue_for(nil)

    ordered = site.verification_requests.open.by_priority.pluck(:slot_key)
    levels = site.required_slots.index_by(&:key)

    ranks = ordered.map { |k| Verification::Requester::LEVEL_RANK.fetch(levels[k].level) }
    expect(ranks).to eq(ranks.sort.reverse), "minimum, then standard, then enriched"
  end

  it "does not ask the same thing twice when the page is regenerated" do
    generate!
    before = site.verification_requests.count

    stub_generation
    Content::GenerateJob.perform_now(site.id, "top")

    expect(site.verification_requests.count).to eq(before)
  end

  it "stops asking once the slot is answered, without deleting the question" do
    generate!
    request = site.verification_requests.find_by(slot_key: "hours")

    entity = site.primary_entity
    fact = entity.facts.create!(attribute_key: "営業時間", slot_key: "hours", value_json: { "value" => "7時-17時" }, confidence: 0.9)
    fact.accept!(evidence: owner_evidence(site, text: "7時から17時まで開けています"))
    described_class.new(site.reload).issue_for(nil)

    expect(request.reload.status).to eq("superseded")
    expect(VerificationRequest.find_by(id: request.id)).to be_present, "nothing is deleted"
  end

  it "does not ask a media site about opening hours" do
    media = Site.current
    media.site_archetypes.destroy_all
    media.update!(primary_archetype: nil)
    media.add_archetype(:media, primary: true)

    described_class.new(media.reload).issue_for(nil)

    expect(media.verification_requests.pluck(:slot_key)).not_to include("hours"),
      "media has no hours slot, so the question never arises"
  end
end
