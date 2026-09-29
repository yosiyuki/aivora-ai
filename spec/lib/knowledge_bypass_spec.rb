require "rails_helper"

# The knowledge invariants (versioning, provenance, no deletion) live in
# ActiveRecord callbacks and validations. These APIs skip them, so they must
# not appear in code that touches knowledge tables. Database-level enforcement
# is a separate follow-up; until then this is the fence.
RSpec.describe "Knowledge tables are never written through bypass APIs" do
  BYPASS = /\.(delete_all|destroy_all|update_all|update_columns|update_column|insert_all|upsert_all|delete)\b(?!\?)/
  ALLOWED = {
    "app/models/site.rb" => [ "site_archetypes.primary.update_all" ],   # site_archetypes is site state, not knowledge
    "app/models/interview_turn.rb" => [ 'extraction_status: "pending").update_all' ],  # the atomic extraction claim; not knowledge
    # Same atomic claim, same reasoning: the row is an answer awaiting
    # extraction, not knowledge, and only extraction_status moves — the
    # owner's words are frozen by readonly?.
    "app/models/verification_event.rb" => [ 'extraction_status: "pending").update_all' ],
    # Rack session and cookie jar, not ActiveRecord.
    "app/controllers/concerns/authentication.rb" => [ "session.delete(", "cookies.delete(" ]
  }.freeze

  # Everything that can reach a knowledge table, not only the models. A
  # Fact.delete_all in a job or a rake task used to pass unnoticed.
  SCANNED = %w[app/**/*.rb lib/**/*.rb].freeze

  it "finds no bypass call anywhere application code can reach a knowledge table" do
    offenders = Dir[*SCANNED.map { |g| Rails.root.join(g) }].flat_map do |path|
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
