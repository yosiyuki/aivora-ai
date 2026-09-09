# A raw item as fetched (DatabaseSchema §5). Untrusted input enters the
# system here and nowhere else; extraction reads raw_content.
class SourceItem < ApplicationRecord
  belongs_to :source

  validates :raw_content, presence: true
  validates :checksum, presence: true, uniqueness: { scope: :source_id }

  before_validation { self.checksum ||= Digest::SHA256.hexdigest(raw_content.to_s) }
  before_validation { self.fetched_at ||= Time.current }

  delegate :site, :trust_level, :owner?, to: :source
end
