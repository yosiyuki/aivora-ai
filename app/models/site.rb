# The single site this deployment publishes (1 deployment = 1 customer = 1 site).
# The table keeps the full column set from DatabaseSchema §3 so site_id stays
# meaningful everywhere, but only one row may exist in Phase 1.
class Site < ApplicationRecord
  STATUSES = %w[setup active].freeze
  HOSTNAME = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\z/

  # Accept a pasted URL ("https://example.com/path") and keep only the host.
  normalizes :domain, with: ->(d) { extract_host(d) }

  validates :name, presence: true
  validates :domain, presence: true, format: { with: HOSTNAME, message: :invalid_hostname }
  validates :primary_language, presence: true
  validates :timezone, presence: true, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:name) } }
  validates :status, inclusion: { in: STATUSES }
  validate :only_one_site

  def self.current = first

  def self.extract_host(value)
    value = value.to_s.strip
    value = "//#{value}" unless value.include?("://") || value.start_with?("//")
    (URI.parse(value).host || "").downcase.delete_suffix(".")
  rescue URI::InvalidURIError
    value.downcase
  end

  private

  def only_one_site
    return unless Site.where.not(id: id).exists?

    errors.add(:base, :only_one_site)
  end
end
