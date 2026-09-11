# Read-only, product-fixed structure for each archetype: which pages a site of
# that kind has and which knowledge slots it needs (README §28). Loaded from
# config/archetypes/*.yml at boot; there is deliberately no table, so the
# repository is the single source of truth and the LLM can only pick one.
class ArchetypeDefinition
  LEVELS = %w[minimum standard enriched].freeze
  KINDS = %w[verifiable experiential].freeze

  Slot = Data.define(:key, :label, :level, :kind, :weight) do
    def minimum? = level == "minimum"
  end

  attr_reader :archetype, :label, :default_metric, :page_structure

  class << self
    def all = (@all ||= load_all.freeze)
    def keys = all.map(&:archetype)
    def find(key)
      all.find { |d| d.archetype == key.to_s } || raise(ArgumentError, "unknown archetype #{key.inspect}")
    end
    def exists?(key) = all.any? { |d| d.archetype == key.to_s }
    def reset! = (@all = nil)

    private

    def load_all
      Rails.root.glob("config/archetypes/*.yml").sort.map do |path|
        new(**YAML.safe_load_file(path, symbolize_names: true)).tap(&:validate!)
      end
    end
  end

  def initialize(archetype:, label:, default_metric:, page_structure:, slots:)
    @archetype = archetype.to_s
    @label = label
    @default_metric = default_metric.to_s
    @page_structure = page_structure.map(&:to_s).freeze
    @slots = slots.map { |s| Slot.new(key: s[:key].to_s, label: s[:label], level: s[:level].to_s, kind: s[:kind].to_s, weight: s[:weight].to_f) }.freeze
  end

  # All slots, or only those at one level: slots(level: :minimum).
  def slots(level: nil) = level ? @slots.select { |s| s.level == level.to_s } : @slots
  def slots_at(level) = slots(level: level)
  def minimum_slots = slots(level: :minimum)
  def slot(key) = slots.find { |s| s.key == key.to_s }

  def validate!
    raise ArgumentError, "#{archetype}: slot keys must be unique" if slots.map(&:key).uniq.size != slots.size
    slots.each do |s|
      raise ArgumentError, "#{archetype}/#{s.key}: level must be one of #{LEVELS.join(', ')}" unless LEVELS.include?(s.level)
      raise ArgumentError, "#{archetype}/#{s.key}: kind must be one of #{KINDS.join(', ')}" unless KINDS.include?(s.kind)
      raise ArgumentError, "#{archetype}/#{s.key}: weight must be within 0..1" unless (0.0..1.0).cover?(s.weight)
    end
    raise ArgumentError, "#{archetype}: needs at least one minimum slot" if minimum_slots.empty?
    self
  end
end
