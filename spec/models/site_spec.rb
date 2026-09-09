require "rails_helper"

RSpec.describe Site, type: :model do
  it "applies the Phase 1 defaults" do
    site = create_site
    expect(site.primary_language).to eq("ja")
    expect(site.timezone).to eq("Asia/Tokyo")
    expect(site.status).to eq("setup")
    expect(site.user_role).to be_nil
    expect(site.primary_archetype).to be_nil
  end

  it "allows exactly one site per deployment" do
    create_site
    second = Site.new(name: "もう一つ", domain: "other.example")
    expect(second).not_to be_valid
    expect(second.errors[:base]).to include(I18n.t("activerecord.errors.models.site.attributes.base.only_one_site"))
    expect(Site.current).to eq(Site.first)
  end

  it "keeps only the host when a URL is pasted as the domain" do
    expect(Site.new(domain: "https://Example.com/path?x=1").domain).to eq("example.com")
    expect(Site.new(domain: "example.com:3000").domain).to eq("example.com")
    expect(Site.new(domain: " example.com. ").domain).to eq("example.com")
  end

  it "rejects values that are not hostnames" do
    %w[exa_mple.com -bad.com bad-.com].each do |bad|
      expect(Site.new(name: "x", domain: bad)).not_to be_valid, bad
    end
    expect(Site.new(name: "x", domain: "localhost")).to be_valid
  end

  it "rejects an unknown timezone or status" do
    expect(Site.new(name: "x", domain: "example.com", timezone: "Mars/Olympus")).not_to be_valid
    expect(Site.new(name: "x", domain: "example.com", status: "gone")).not_to be_valid
  end
end
