# Tenant integrity inside a record: every association a knowledge row points
# at must belong to the same site as the row itself. Without this, a
# cross-tenant link can be assembled piecewise and pass the pairwise check
# in Evidenced#add_evidence!.
module SameSite
  extend ActiveSupport::Concern

  class_methods do
    def same_site_as(*associations)
      validate do
        associations.each do |name|
          other = public_send(name) or next
          other_site_id = other.respond_to?(:site_id) ? other.site_id : other.site&.id
          errors.add(name, :other_site) if site_id && other_site_id && other_site_id != site_id
        end
      end
    end
  end
end
