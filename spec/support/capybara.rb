require "capybara/rspec"

# Nothing in the admin surface needs JavaScript yet, so system specs run on
# rack_test: no browser process, no waiting. Add `js: true` to an example only
# when the behaviour under test genuinely needs a browser.
Capybara.default_max_wait_time = 2

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.define_derived_metadata(file_path: %r{spec/system/}) do |metadata|
    metadata[:type] ||= :system
    metadata[:slow] = true
  end
end
