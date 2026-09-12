# What the user wants the site to achieve, in their own words. Deliberately
# not part of Knowledge: intent must never be mistaken for fact.
class Goal < ApplicationRecord
  STATUSES = %w[proposed active retired].freeze

  belongs_to :site
  belongs_to :source_item, optional: true

  validates :name, :description, presence: true
  validates :status, inclusion: { in: STATUSES }

  # Quantification is the system's job (README §27.9): the metric comes from
  # the archetype definition, not from the model or the user.
  def adopt_archetype!(definition)
    update!(archetype: definition.archetype, metric: metric.presence || definition.default_metric)
  end
end
