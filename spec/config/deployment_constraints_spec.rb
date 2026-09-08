require "rails_helper"

# Guards for the deployment constraints in Technical Architecture §40-47.
# These read the repository files rather than booting production, so they run
# anywhere and fail the moment someone adds a forbidden dependency.
RSpec.describe "Deployment constraints" do
  let(:root) { Rails.root }
  let(:lockfile) { root.join("Gemfile.lock").read }

  it "does not depend on Redis or any stateful component other than PostgreSQL" do
    %w[redis hiredis sidekiq resque elasticsearch neo4j kafka].each do |gem_name|
      expect(lockfile).not_to match(/^\s{4}#{gem_name} \(/), "#{gem_name} must not be a dependency"
    end
  end

  it "keeps pgvector optional" do
    expect(lockfile).not_to match(/^\s{4}neighbor \(/)
    schema = root.join("db/schema.rb")
    expect(schema.read).not_to include('enable_extension "vector"') if schema.exist?
  end

  it "uses a single DATABASE_URL in production, with Solid Queue on the same database" do
    production = YAML.safe_load(ERB.new(root.join("config/database.yml").read).result, aliases: true).fetch("production")
    expect(production.keys).to include("url")
    expect(production.keys).not_to include("queue", "cache", "cable")

    expect(root.join("config/environments/production.rb").read).not_to include("connects_to")
    expect(Rails.application.config.active_job.queue_adapter).to eq(:test) # solid_queue everywhere else
    expect(Dir[root.join("db/migrate/*_create_solid_queue_tables.rb")]).not_to be_empty
    expect(root.join("db/queue_schema.rb")).not_to exist
  end

  it "boots from exactly the three documented environment variables" do
    keys = root.join(".env.example").read.scan(/^([A-Z_]+)=/).flatten
    expect(keys).to contain_exactly("DATABASE_URL", "APP_SECRET", "LLM_API_KEY")

    production_rb = root.join("config/environments/production.rb").read
    expect(production_rb).to include('ENV.fetch("APP_SECRET")')
    expect(production_rb).to include("config.require_master_key = false")
    expect(root.join("config/credentials.yml.enc")).not_to exist
  end

  it "exposes every process role through bin/process and the Procfile" do
    procfile = root.join("Procfile").read
    process = root.join("bin/process").read
    %w[web public worker scheduler release].each do |role|
      expect(procfile).to match(/^#{role}: bin\/process #{role}$/)
      expect(process).to include("#{role})")
    end
    expect(root.join("bin/process")).to be_executable
  end
end
