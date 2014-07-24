# A BlockedEmail record represents an email address that is being watched,
# typically when creating a new User account. If the email of the signup form
# (or some other form) matches a BlockedEmail record, an action can be
# performed based on the action_type.
class BlockedEmail < ActiveRecord::Base

  before_validation :set_defaults

  validates :email, presence: true, uniqueness: true

  def self.actions
    @actions ||= Enum.new(:block, :do_nothing)
  end

  def self.block(email, opts={})
    find_by_email(email) || create(opts.slice(:action_type).merge({email: email}))
  end

  def self.should_block?(email)
    blocked_email = BlockedEmail.where(email: email).first
    blocked_email.record_match! if blocked_email
    blocked_email && blocked_email.action_type == actions[:block]
  end

  def set_defaults
    self.action_type ||= BlockedEmail.actions[:block]
  end

  def record_match!
    self.match_count += 1
    self.last_match_at = Time.zone.now
    save
  end

end

# == Schema Information
#
# Table name: blocked_emails
#
#  id            :integer          not null, primary key
#  email         :string(255)      not null
#  action_type   :integer          not null
#  match_count   :integer          default(0), not null
#  last_match_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_blocked_emails_on_email          (email) UNIQUE
#  index_blocked_emails_on_last_match_at  (last_match_at)
#
