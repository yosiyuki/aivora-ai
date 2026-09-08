# The deployment's administrator. Phase 1 has exactly one customer per
# deployment, so there are no roles and no site_id here: a user owns the
# deployment, not a row in sites.
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
end
