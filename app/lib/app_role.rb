# Which role this process is serving. One image, several roles (Technical Architecture §46).
#
#   web    - admin / review UI plus the public pages
#   public - public pages only, for PaaS setups that can route traffic separately
#
# worker and scheduler do not boot the HTTP stack and never consult this.
module AppRole
  ROLES = %w[web public].freeze

  def self.current
    role = Rails.application.config.x.app_role.to_s
    raise ArgumentError, "unknown APP_ROLE #{role.inspect}; expected one of #{ROLES.join(', ')}" unless ROLES.include?(role)

    role
  end

  def self.web? = current == "web"
  def self.public? = current == "public"
end
