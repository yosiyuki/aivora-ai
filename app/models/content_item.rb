# A page this site publishes (DatabaseSchema §27). The URL is issued once and
# never changes; a page is unpublished by status, never deleted; and only a
# version that passed grounding can be the published one.
class ContentItem < ApplicationRecord
  CONTENT_TYPES = %w[page article].freeze
  STATUSES = %w[draft generating published unpublished].freeze
  URL_FORMAT = %r{\A/(?:[a-z0-9\-]+(?:/[a-z0-9\-]+)*)?\z}

  belongs_to :site
  has_many :versions, -> { order(:version) }, class_name: "ContentVersion", dependent: :restrict_with_exception
  belongs_to :published_version, class_name: "ContentVersion", optional: true

  attr_readonly :url

  validates :content_type, inclusion: { in: CONTENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :archetype_page_type, presence: true
  validates :url, presence: true, format: { with: URL_FORMAT, message: :invalid_path }, uniqueness: { scope: :site_id }
  validates :language, presence: true
  validate :url_is_immutable, on: :update
  validate :published_version_belongs_here_and_passed

  before_validation { self.language ||= site&.primary_language }

  # top lives at "/", everything else under its page type.
  def self.url_for(page_type, slug: nil)
    return "/" if page_type.to_s == "top"

    slug.present? ? "/#{page_type}/#{slug}" : "/#{page_type}"
  end

  def published? = status == "published"
  def generating? = status == "generating"
  def latest_version = versions.last
  def next_version_number = versions.maximum(:version).to_i + 1

  def publish!(version)
    raise ArgumentError, "version #{version.id} belongs to another item" unless version.content_item_id == id
    raise ArgumentError, "only a version that passed grounding can be published" unless version.passed?

    update!(status: "published", published_version: version, title: version.title, published_at: published_at || Time.current)
  end

  # Nothing is deleted: the published version stays referenced for restore.
  def unpublish! = update!(status: "unpublished")

  private

  def url_is_immutable
    errors.add(:url, :immutable) if will_save_change_to_url?
  end

  def published_version_belongs_here_and_passed
    return if published_version.nil?

    errors.add(:published_version, :other_item) if published_version.content_item_id != id
    errors.add(:published_version, :not_grounded) unless published_version.passed?
  end
end
