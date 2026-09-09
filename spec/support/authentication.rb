module AuthenticationHelper
  def create_admin(email_address: "admin@example.com", password: "correct horse battery", name: "管理者")
    User.create!(name:, email_address:, password:, password_confirmation: password)
  end

  def create_site(name: "テストサイト", domain: "example.com")
    Site.create!(name:, domain:)
  end

  def sign_in(user, password: "correct horse battery")
    post session_path, params: { email_address: user.email_address, password: }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :model
  config.include AuthenticationHelper, type: :task
  config.include AuthenticationHelper, type: :system
end
