require "rails_helper"

RSpec.describe AppRole do
  it "defaults to web" do
    with_app_role("web") do
      expect(described_class.current).to eq("web")
      expect(described_class).to be_web
      expect(described_class).not_to be_public
    end
  end

  it "recognises the public role" do
    with_app_role("public") do
      expect(described_class).to be_public
      expect(described_class).not_to be_web
    end
  end

  it "rejects unknown roles so a typo in APP_ROLE fails loudly" do
    Rails.application.config.x.app_role = "wrb"
    expect { described_class.current }.to raise_error(ArgumentError, /unknown APP_ROLE/)
  ensure
    Rails.application.config.x.app_role = "web"
  end
end
