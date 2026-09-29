require "rails_helper"

RSpec.describe Content::Throttle do
  let!(:site) { cafe_site }

  def page!(page_type, versions: 1, at: Time.current)
    item = site.content_items.find_or_create_by!(url: ContentItem.url_for(page_type)) { |i| i.archetype_page_type = page_type }
    versions.times { item.append_version!(body: "x", created_at: at) }
    item
  end

  def fresh = Current.content_throttles = nil

  it "counts a page's first version as new and later ones as changes" do
    page!("faq", versions: 3)

    t = described_class.for(site)

    expect(t.new_pages_this_week).to eq(1)
    expect(t.changes_today).to eq(2)
  end

  it "uses the site's own week and day, not the server's" do
    site.update!(timezone: "Asia/Tokyo")
    travel_to Time.utc(2026, 9, 27, 16, 0) do   # Sunday 16:00 UTC = Monday 01:00 Tokyo: a new week there
      page!("faq", at: Time.utc(2026, 9, 27, 14, 0))   # Sunday 23:00 Tokyo: last week
      fresh

      expect(described_class.for(site).new_pages_this_week).to eq(0)
    end
  end

  it "allows a new page until the weekly cap and then defers" do
    site.policy.update!(max_new_pages_per_week: 2)
    page!("faq"); page!("news")
    fresh

    t = described_class.for(site)

    expect(t.new_page_allowed?).to be(false)
    expect(t.allowed_for?("services")).to be(false), "services has no version, so it is a new page"
    expect(t.allowed_for?("faq")).to be(true), "faq exists, so regenerating it is a change, under a different cap"
  end

  it "allows a change until the daily cap and then defers" do
    site.policy.update!(max_pages_changed_per_day: 1)
    page!("faq", versions: 2)
    fresh

    t = described_class.for(site)

    expect(t.change_allowed?).to be(false)
    expect(t.allowed_for?("faq")).to be(false)
    expect(t.allowed_for?("services")).to be(true), "a new page is still fine"
  end

  it "falls back to the conservative default when a cap column is NULL" do
    site.policy.update_columns(max_new_pages_per_week: nil, max_pages_changed_per_day: nil)

    expect(site.policy.reload.new_pages_per_week_cap).to eq(SitePolicy::DEFAULT_MAX_NEW_PAGES_PER_WEEK)
    expect(site.policy.pages_changed_per_day_cap).to eq(SitePolicy::DEFAULT_MAX_PAGES_CHANGED_PER_DAY)
  end

  it "is resolved once per request" do
    expect(described_class.for(site)).to equal(described_class.for(site))
  end
end
