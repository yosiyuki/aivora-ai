require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AivoraAi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
    config.generators.template_engine = :slim

    # The product is Japanese-first; validation messages come from rails-i18n.
    config.i18n.default_locale = :ja
    config.i18n.available_locales = %i[ja en]

    # Background work goes through Solid Queue on the primary PostgreSQL database.
    # No Redis. Test overrides this with the :test adapter.
    config.active_job.queue_adapter = :solid_queue

    # Which process role this instance is serving (web | public). See AppRole.
    config.x.app_role = ENV.fetch("APP_ROLE", "web")

    # LLM API key is read at boot but not required to boot. Routing and pricing
    # tables live in config/llm.yml and config/llm_pricing.yml.
    config.x.llm.api_key = ENV["LLM_API_KEY"]
    config.x.llm.routing = config_for(:llm)
    config.x.llm.pricing = config_for(:llm_pricing)
  end
end
