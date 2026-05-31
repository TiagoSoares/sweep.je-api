class User < ApplicationRecord
  include HasPublicId

  has_secure_password

  has_many :sweepstakes, dependent: :destroy

  # Organizers create/run sweepstakes; admins additionally manage templates (§2).
  enum :role, { organizer: 0, admin: 1 }, default: :organizer

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email,
            presence: true,
            length: { maximum: 255 },
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  # has_secure_password already caps length at 72 bytes (bcrypt's limit).
  validates :password, length: { minimum: 8 }, allow_nil: true
end
