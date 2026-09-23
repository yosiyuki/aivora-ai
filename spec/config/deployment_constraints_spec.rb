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

  it "serves generated pages from the app on every HTTP role, admin only on web" do
    public_routes = root.join("config/routes/public.rb").read
    expect(public_routes).to include("public/pages#show")

    # The catch-all must be drawn after the admin routes or it swallows them.
    main = root.join("config/routes.rb").read
    expect(main.index("draw(:admin)")).to be < main.index("draw(:public)")

    # Pages are rendered on request, not exported to disk (§45).
    expect(public_routes).not_to match(/send_file|Dir\.|File\.write/)
  end

  it "keeps observing on a schedule, which is what stops stale facts going unnoticed" do
    recurring = YAML.safe_load(ERB.new(root.join("config/recurring.yml").read).result, aliases: true).fetch("production")

    expect(recurring).to include("verify_fact_staleness")
    expect(recurring.dig("verify_fact_staleness", "class")).to eq("Verification::StalenessJob")

    # Observation is fixed cost and must not depend on the generation budget
    # (README §33), which holds here because the job calls no model at all.
    job = root.join("app/jobs/verification/staleness_job.rb").read
    expect(job).not_to match(/Llm::/)
  end
end
