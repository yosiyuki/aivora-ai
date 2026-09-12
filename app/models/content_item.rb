# A page this site publishes (DatabaseSchema §27). The URL is issued once and
# never changes; a page is unpublished by status, never deleted; and only a
# version that passed grounding can be the published one.
class ContentItem < ApplicationRecord
  CONTENT_TYPES = %w[page article].freeze
  STATUSES = %w[draft generating published unpublished].freeze
  URL_FORMAT = %r{\A/(?:[a-z0-9\-]+(?:/[a-z0-9\-]+)*)?\z}

  belongs_to :site
  has_many :versions, -> { order(:version) }, class_name: "ContentVersion", dependent: :restrict_with_exception
  has_one :latest_version, -> { order(version: :desc) }, class_name: "ContentVersion"
  belongs_to :published_version, class_name: "ContentVersion", optional: true

  attr_readonly :url

  validates :content_type, inclusion: { in: CONTENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :archetype_page_type, presence: true
  validates :url, presence: true, format: { with: URL_FORMAT, message: :invalid_path }, uniqueness: { scope: :site_id }
  validates :language, presence: true
  validate :url_is_immutable, on: :update
  validate :published_state_is_consistent
  validate :published_only_through_publish

  before_validation { self.language ||= site&.primary_language }
  before_destroy { raise ActiveRecord::RecordNotDestroyed.new("content is never physically deleted", self) }

  # top lives at "/", everything else under its page type.
  def self.url_for(page_type, slug: nil)
    return "/" if page_type.to_s == "top"

    slug.present? ? "/#{page_type}/#{slug}" : "/#{page_type}"
  end

  def published? = status == "published"
  def generating? = status == "generating"
  def next_version_number = versions.maximum(:version).to_i + 1

  # The only way a page becomes published, or points at a new version.
  def publish!(version)
    raise ArgumentError, "version #{version.id} belongs to another item" unless version.content_item_id == id
    raise ArgumentError, "only a version that passed grounding can be published" unless version.passed?

    @publishing = true
    update!(status: "published", published_version: version, title: version.title, published_at: published_at || Time.current)
  ensure
    @publishing = false
  end

  # Nothing is deleted: the published version stays referenced for restore.
  def unpublish! = update!(status: "unpublished")

  # Versions are numbered under the item's row lock, so two appends cannot
  # pick the same number.
  def append_version!(attributes)
    with_lock { versions.create!(attributes.merge(version: next_version_number)) }
  end

  GENERATION_LEASE = 30.minutes

  # Claim for background generation, under the row lock: previous status and
  # the claim are read and written in one step, so a state change that lands
  # in between cannot be overwritten later. A claim older than the lease is
  # treated as abandoned (crashed worker) and can be taken over. Returns
  # [item, token, previous_status] or nil.
  def self.claim_for_generation!(site, page_type)
    item = site.content_items.find_or_create_by!(url: url_for(page_type)) do |i|
      i.archetype_page_type = page_type.to_s
      i.content_type = "page"
    end
    item.with_lock do
      return nil if item.generating? && item.updated_at > GENERATION_LEASE.ago

      previous = item.generating? ? (item.generation_previous_status.presence || "draft") : item.status
      token = SecureRandom.hex(8)
      item.update!(status: "generating", generation_token: token, generation_previous_status: previous)
      [ item, token, previous ]
    end
  end

  # Hands the row back only if this claim still holds it (token match).
  # Returning to `published` is a restore of the state the page already had
  # (pointer unchanged), so it is allowed here without going through publish!.
  def release_generation!(token, to:)
    with_lock do
      return false unless generating? && generation_token == token

      @publishing = true if to == "published" && published_version.present?
      update!(status: to, generation_token: nil, generation_previous_status: nil)
      true
    ensure
      @publishing = false
    end
  end

  # A failure after the claim leaves a trace the review UI can show.
  def record_generation_failure!(error, token:, restore_status:)
    transaction do
      append_version!(body: "（生成できませんでした）", source: versions.exists? ? "regenerated" : "generated",
                      metadata: { "error" => { "class" => error.class.name, "message" => error.message.to_s.first(500) } })
        .decide!(:failed)
      release_generation!(token, to: restore_status)
    end
  end

  def failed_last? = latest_version&.failed?

  private

  def url_is_immutable
    errors.add(:url, :immutable) if will_save_change_to_url?
  end

  # status and pointer always agree: published ⇔ a passed version of this item.
  def published_state_is_consistent
    if published? && published_version.nil?
      errors.add(:published_version, :required_when_published)
    end
    return if published_version.nil?

    errors.add(:published_version, :other_item) if published_version.content_item_id != id
    errors.add(:published_version, :not_grounded) unless published_version.passed?
  end

  # Becoming published, or pointing at a different version, happens in publish! only.
  def published_only_through_publish
    return if @publishing

    errors.add(:status, :use_publish) if published? && (new_record? || status_changed?)
    errors.add(:published_version, :use_publish) if published_version_id_changed? && !published_version_id_was.nil?
    errors.add(:published_version, :use_publish) if published_version_id_changed? && published_version_id_was.nil? && published_version_id.present?
  end
end
