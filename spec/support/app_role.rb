# Switch the process role for a block and rebuild the route set to match,
# the same way a fresh boot with APP_ROLE=<role> would.
module AppRoleHelper
  def with_app_role(role)
    previous = Rails.application.config.x.app_role
    Rails.application.config.x.app_role = role
    Rails.application.reload_routes!
    yield
  ensure
    Rails.application.config.x.app_role = previous
    Rails.application.reload_routes!
  end
end

RSpec.configure do |config|
  config.include AppRoleHelper
end
