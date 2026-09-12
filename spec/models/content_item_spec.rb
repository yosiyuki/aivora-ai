require "rails_helper"

RSpec.describe ContentItem, type: :model do
  let!(:site) { create_site }
  let(:item) { site.content_items.create!(archetype_page_type: "top", url: "/") }

  it "issues URLs from the page type and inherits the site language" do
    expect(described_class.url_for("top")).to eq("/")
    expect(described_class.url_for("services")).to eq("/services")
    expect(described_class.url_for("article", slug: "roast")).to eq("/article/roast")
    expect(item.language).to eq("ja")
    expect(site.top_page).to eq(item)
  end

  it "never lets a URL change once issued" do
    # attr_readonly raises on assignment to a persisted record (Rails 7.1+);
    # the validation behind it is a second line of defence.
    expect { item.url = "/moved" }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect { item.update!(url: "/moved") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect(item.reload.url).to eq("/")
  end

  it "rejects malformed paths and duplicate URLs per site" do
    expect(site.content_items.build(archetype_page_type: "x", url: "services")).not_to be_valid
    expect(site.content_items.build(archetype_page_type: "x", url: "/Services")).not_to be_valid
    item
    expect(site.content_items.build(archetype_page_type: "x", url: "/")).not_to be_valid
  end

  it "publishes only a version that passed grounding" do
    failed = item.versions.create!(body: "x", grounding_status: "failed")
    expect { item.publish!(failed) }.to raise_error(ArgumentError, /passed grounding/)
    expect(item.reload).not_to be_published

    passed = item.versions.create!(title: "渋谷のカフェ", body: "本文", grounding_status: "passed")
    item.publish!(passed)
    expect(item.reload).to have_attributes(status: "published", published_version: passed, title: "渋谷のカフェ")
    expect(item.published_at).to be_present

    other = site.content_items.create!(archetype_page_type: "faq", url: "/faq")
    expect { other.publish!(passed) }.to raise_error(ArgumentError, /another item/)
  end

  it "keeps every version and the published pointer when unpublished" do
    v1 = item.versions.create!(body: "一", grounding_status: "passed")
    v2 = item.versions.create!(body: "二", grounding_status: "passed")
    expect(item.versions.pluck(:version)).to eq([ 1, 2 ])
    item.publish!(v1)
    item.unpublish!
    expect(item.reload).to have_attributes(status: "unpublished", published_version: v1)
    expect(v2.reload).to be_persisted
    expect { item.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end
