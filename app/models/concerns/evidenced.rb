# Provenance: which evidence a piece of knowledge rests on (DatabaseSchema §19).
# Old evidence is kept when knowledge changes; links are only ever added.
module Evidenced
  extend ActiveSupport::Concern

  included do
    has_many :evidence_links, as: :knowledge, dependent: :destroy
  end

  def evidence = Evidence.where(id: evidence_links.select(:evidence_id))
  def provenanced? = evidence_links.exists?

  def add_evidence!(evidence, relation: "supports")
    raise ArgumentError, "evidence belongs to another site" if evidence.site_id != site_id

    evidence_links.find_or_create_by!(evidence: evidence, relation_type: relation)
  end
end
