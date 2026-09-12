RSpec.configure do |config|
  config.before(:each) { Llm::Fake.reset! }
end
