require "rails_helper"

# The knowledge invariants (versioning, provenance, no deletion) live in
# ActiveRecord callbacks and validations. These APIs skip them, so they must
# not appear in code that touches knowledge tables. Database-level enforcement
# is a separate follow-up; until then this is the fence.
RSpec.describe "Knowledge tables are never written through bypass APIs" do
  BYPASS = /\.(delete_all|update_all|update_columns|update_column|insert_all|upsert_all|delete)\b(?!\?)/
  ALLOWED = {
    "app/models/site.rb" => [ "site_archetypes.primary.update_all" ],   # site_archetypes is site state, not knowledge
    "app/models/interview_turn.rb" => [ 'extraction_status: "pending").update_all' ]  # the atomic extraction claim; not knowledge
  }.freeze

  it "finds no bypass call in models, concerns, or the extraction pipeline" do
    offenders = Dir[Rails.root.join("app/models/**/*.rb"), Rails.root.join("app/lib/**/*.rb")].flat_map do |path|
      rel = path.delete_prefix("#{Rails.root}/")
      File.readlines(path).each_with_index.filter_map do |line, i|
        next unless line.match?(BYPASS)
        next if ALLOWED.fetch(rel, []).any? { |ok| line.include?(ok) }

        "#{rel}:#{i + 1}: #{line.strip}"
      end
    end
    expect(offenders).to be_empty, offenders.join("\n")
  end
end
