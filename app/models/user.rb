require_dependency 'email'
require_dependency 'email_token'
require_dependency 'trust_level'
require_dependency 'pbkdf2'
require_dependency 'summarize'
require_dependency 'discourse'
require_dependency 'post_destroyer'
require_dependency 'user_name_suggester'
require_dependency 'pretty_text'
require_dependency 'url_helper'

class User < ActiveRecord::Base
  include Roleable
  include UrlHelper
  include HasCustomFields

  has_many :posts
  has_many :notifications, dependent: :destroy
  has_many :topic_users, dependent: :destroy
  has_many :topics
  has_many :user_open_ids, dependent: :destroy
  has_many :user_actions, dependent: :destroy
  has_many :post_actions, dependent: :destroy
  has_many :user_badges, dependent: :destroy
  has_many :email_logs, dependent: :destroy
  has_many :post_timings
  has_many :topic_allowed_users, dependent: :destroy
  has_many :topics_allowed, through: :topic_allowed_users, source: :topic
  has_many :email_tokens, dependent: :destroy
  has_many :views
  has_many :user_visits, dependent: :destroy
  has_many :invites, dependent: :destroy
  has_many :topic_links, dependent: :destroy
  has_many :uploads

  has_one :facebook_user_info, dependent: :destroy
  has_one :twitter_user_info, dependent: :destroy
  has_one :github_user_info, dependent: :destroy
  has_one :oauth2_user_info, dependent: :destroy
  has_one :user_stat, dependent: :destroy
  has_one :single_sign_on_record, dependent: :destroy
  belongs_to :approved_by, class_name: 'User'
  belongs_to :primary_group, class_name: 'Group'

  has_many :group_users, dependent: :destroy
  has_many :groups, through: :group_users
  has_many :secure_categories, through: :groups, source: :categories

  has_one :user_search_data, dependent: :destroy
  has_one :api_key, dependent: :destroy

  belongs_to :uploaded_avatar, class_name: 'Upload', dependent: :destroy

  delegate :last_sent_email_address, :to => :email_logs

  validates_presence_of :username
  validate :username_validator
  validates :email, presence: true, uniqueness: true
  validates :email, email: true, if: :email_changed?
  validate :password_validator
  validates :ip_address, allowed_ip_address: {on: :create, message: :signup_not_allowed}

  before_save :cook
  before_save :update_username_lower
  before_save :ensure_password_is_hashed
  after_initialize :add_trust_level
  after_initialize :set_default_email_digest
  after_initialize :set_default_external_links_in_new_tab

  after_save :update_tracked_topics
  after_save :clear_global_notice_if_needed

  after_create :create_email_token
  after_create :create_user_stat

  before_destroy do
    # These tables don't have primary keys, so destroying them with activerecord is tricky:
    PostTiming.delete_all(user_id: self.id)
    View.delete_all(user_id: self.id)
  end

  # Whether we need to be sending a system message after creation
  attr_accessor :send_welcome_message

  # This is just used to pass some information into the serializer
  attr_accessor :notification_channel_position

  scope :blocked, -> { where(blocked: true) } # no index
  scope :not_blocked, -> { where(blocked: false) } # no index
  scope :suspended, -> { where('suspended_till IS NOT NULL AND suspended_till > ?', Time.zone.now) } # no index
  scope :not_suspended, -> { where('suspended_till IS NULL') }
  # excluding fake users like the community user
  scope :real, -> { where('id > 0') }

  module NewTopicDuration
    ALWAYS = -1
    LAST_VISIT = -2
  end

  GLOBAL_USERNAME_LENGTH_RANGE = 3..15

  def self.username_length
    if SiteSetting.enforce_global_nicknames
      GLOBAL_USERNAME_LENGTH_RANGE
    else
      SiteSetting.min_username_length.to_i..SiteSetting.max_username_length.to_i
    end
  end

  def custom_groups
    groups.where(automatic: false, visible: true)
  end

  def self.username_available?(username)
    lower = username.downcase
    User.where(username_lower: lower).blank?
  end

  EMAIL = %r{([^@]+)@([^\.]+)}

  def self.new_from_params(params)
    user = User.new
    user.name = params[:name]
    user.email = params[:email]
    user.password = params[:password]
    user.username = params[:username]
    user
  end

  def self.suggest_name(email)
    return "" unless email
    name = email.split(/[@\+]/)[0]
    name = name.gsub(".", " ")
    name.titleize
  end

  # Find a user by temporary key, nil if not found or key is invalid
  def self.find_by_temporary_key(key)
    user_id = $redis.get("temporary_key:#{key}")
    if user_id.present?
      find_by(id: user_id.to_i)
    end
  end

  def self.find_by_username_or_email(username_or_email)
    if username_or_email.include?('@')
      find_by_email(username_or_email)
    else
      find_by_username(username_or_email)
    end
  end

  def self.find_by_email(email)
    find_by(email: Email.downcase(email))
  end

  def self.find_by_username(username)
    find_by(username_lower: username.downcase)
  end


  def enqueue_welcome_message(message_type)
    return unless SiteSetting.send_welcome_message?
    Jobs.enqueue(:send_system_message, user_id: id, message_type: message_type)
  end

  def change_username(new_username)
    current_username = self.username
    self.username = new_username

    if current_username.downcase != new_username.downcase && valid?
      DiscourseHub.username_operation { DiscourseHub.change_username(current_username, new_username) }
    end

    save
  end

  # Use a temporary key to find this user, store it in redis with an expiry
  def temporary_key
    key = SecureRandom.hex(32)
    $redis.setex "temporary_key:#{key}", 1.week, id.to_s
    key
  end

  def created_topic_count
    topics.count
  end

  # tricky, we need our bus to be subscribed from the right spot
  def sync_notification_channel_position
    @unread_notifications_by_type = nil
    self.notification_channel_position = MessageBus.last_id("/notification/#{id}")
  end

  def invited_by
    used_invite = invites.where("redeemed_at is not null").includes(:invited_by).first
    used_invite.try(:invited_by)
  end

  # Approve this user
  def approve(approved_by, send_mail=true)
    self.approved = true

    if approved_by.is_a?(Fixnum)
      self.approved_by_id = approved_by
    else
      self.approved_by = approved_by
    end

    self.approved_at = Time.now

    send_approval_email if save and send_mail
  end

  def self.email_hash(email)
    Digest::MD5.hexdigest(email.strip.downcase)
  end

  def email_hash
    User.email_hash(email)
  end

  def unread_notifications_by_type
    @unread_notifications_by_type ||= notifications.where("id > ? and read = false", seen_notification_id).group(:notification_type).count
  end

  def reload
    @unread_notifications_by_type = nil
    @unread_pms = nil
    super
  end

  def unread_private_messages
    @unread_pms ||= notifications.where("read = false AND notification_type = ?", Notification.types[:private_message]).count
  end

  def unread_notifications
    unread_notifications_by_type.except(Notification.types[:private_message]).values.sum
  end

  def saw_notification_id(notification_id)
    User.where(["id = ? and seen_notification_id < ?", id, notification_id])
        .update_all ["seen_notification_id = ?", notification_id]
  end

  def publish_notifications_state
    MessageBus.publish("/notification/#{id}",
                       {unread_notifications: unread_notifications,
                        unread_private_messages: unread_private_messages},
                       user_ids: [id] # only publish the notification to this user
    )
  end

  # A selection of people to autocomplete on @mention
  def self.mentionable_usernames
    User.select(:username).order('last_posted_at desc').limit(20)
  end

  def password=(password)
    # special case for passwordless accounts
    @raw_password = password unless password.blank?
  end

  def password
    '' # so that validator doesn't complain that a password attribute doesn't exist
  end

  # Indicate that this is NOT a passwordless account for the purposes of validation
  def password_required!
    @password_required = true
  end

  def password_required?
    !!@password_required
  end

  def has_password?
    password_hash.present?
  end

  def password_validator
    PasswordValidator.new(attributes: :password).validate_each(self, :password, @raw_password)
  end

  def confirm_password?(password)
    return false unless password_hash && salt
    self.password_hash == hash_password(password, salt)
  end

  def new_user?
    created_at >= 24.hours.ago || trust_level == TrustLevel.levels[:newuser]
  end

  def seen_before?
    last_seen_at.present?
  end

  def visit_record_for(date)
    user_visits.find_by(visited_at: date)
  end

  def update_visit_record!(date)
    create_visit_record!(date) unless visit_record_for(date)
  end

  def update_posts_read!(num_posts, now=Time.zone.now)
    if user_visit = visit_record_for(now.to_date)
      user_visit.posts_read += num_posts
      user_visit.save
      user_visit
    else
      create_visit_record!(now.to_date, num_posts)
    end
  end

  def update_ip_address!(new_ip_address)
    unless ip_address == new_ip_address || new_ip_address.blank?
      update_column(:ip_address, new_ip_address)
    end
  end

  def update_last_seen!(now=Time.zone.now)
    now_date = now.to_date
    # Only update last seen once every minute
    redis_key = "user:#{id}:#{now_date}"
    return unless $redis.setnx(redis_key, "1")

    $redis.expire(redis_key, SiteSetting.active_user_rate_limit_secs)
    update_previous_visit(now)
    # using update_column to avoid the AR transaction
    update_column(:last_seen_at, now)
  end

  def self.gravatar_template(email)
    email_hash = self.email_hash(email)
    "//www.gravatar.com/avatar/#{email_hash}.png?s={size}&r=pg&d=identicon"
  end

  # Don't pass this up to the client - it's meant for server side use
  # This is used in
  #   - self oneboxes in open graph data
  #   - emails
  def small_avatar_url
    template = avatar_template
    schemaless template.gsub("{size}", "45")
  end

  # the avatars might take a while to generate
  # so return the url of the original image in the meantime
  def uploaded_avatar_path
    return unless SiteSetting.allow_uploaded_avatars? && use_uploaded_avatar
    avatar_template = uploaded_avatar_template.present? ? uploaded_avatar_template : uploaded_avatar.try(:url)
    schemaless absolute avatar_template
  end

  def avatar_template
    uploaded_avatar_path || User.gravatar_template(id != -1 ? email : "team@discourse.org")
  end

  # The following count methods are somewhat slow - definitely don't use them in a loop.
  # They might need to be denormalized
  def like_count
    UserAction.where(user_id: id, action_type: UserAction::WAS_LIKED).count
  end

  def post_count
    posts.count
  end

  def first_post
    posts.order('created_at ASC').first
  end

  def flags_given_count
    PostAction.where(user_id: id, post_action_type_id: PostActionType.flag_types.values).count
  end

  def flags_received_count
    posts.includes(:post_actions).where('post_actions.post_action_type_id' => PostActionType.flag_types.values).count
  end

  def private_topics_count
    topics_allowed.where(archetype: Archetype.private_message).count
  end

  def posted_too_much_in_topic?(topic_id)

    # Does not apply to staff, non-new members or your own topics
    return false if staff? ||
                    (trust_level != TrustLevel.levels[:newuser]) ||
                    Topic.where(id: topic_id, user_id: id).exists?

    last_action_in_topic = UserAction.last_action_in_topic(id, topic_id)
    since_reply = Post.where(user_id: id, topic_id: topic_id)
    since_reply = since_reply.where('id > ?', last_action_in_topic) if last_action_in_topic

    (since_reply.count >= SiteSetting.newuser_max_replies_per_topic)
  end

  def bio_excerpt
    excerpt = PrettyText.excerpt(bio_cooked, 350)
    return excerpt if excerpt.blank? || has_trust_level?(:basic)
    PrettyText.strip_links(excerpt)
  end

  def bio_processed
    return bio_cooked if bio_cooked.blank? || has_trust_level?(:basic)
    PrettyText.strip_links(bio_cooked)
  end

  def delete_all_posts!(guardian)
    raise Discourse::InvalidAccess unless guardian.can_delete_all_posts? self

    posts.order("post_number desc").each do |p|
      PostDestroyer.new(guardian.user, p).destroy
    end
  end

  def suspended?
    suspended_till && suspended_till > DateTime.now
  end

  def suspend_record
    UserHistory.for(self, :suspend_user).order('id DESC').first
  end

  def suspend_reason
    suspend_record.try(:details) if suspended?
  end

  # Use this helper to determine if the user has a particular trust level.
  # Takes into account admin, etc.
  def has_trust_level?(level)
    raise "Invalid trust level #{level}" unless TrustLevel.valid_level?(level)
    admin? || moderator? || TrustLevel.compare(trust_level, level)
  end

  # a touch faster than automatic
  def admin?
    admin
  end

  def change_trust_level!(level)
    raise "Invalid trust level #{level}" unless TrustLevel.valid_level?(level)
    self.trust_level = TrustLevel.levels[level]
    self.bio_raw_will_change! # So it can get re-cooked based on the new trust level
    transaction do
      self.save!
      Group.user_trust_level_change!(self.id, self.trust_level)
    end
  end

  def guardian
    Guardian.new(self)
  end

  def username_format_validator
    UsernameValidator.perform_validation(self, 'username')
  end

  def email_confirmed?
    email_tokens.where(email: email, confirmed: true).present? || email_tokens.empty?
  end

  def activate
    email_token = self.email_tokens.active.first
    if email_token
      EmailToken.confirm(email_token.token)
    else
      self.active = true
      save
    end
  end

  def deactivate
    self.active = false
    save
  end

  def treat_as_new_topic_start_date
    duration = new_topic_duration_minutes || SiteSetting.new_topic_duration_minutes
    [case duration
      when User::NewTopicDuration::ALWAYS
        created_at
      when User::NewTopicDuration::LAST_VISIT
        previous_visit_at || user_stat.new_since
      else
        duration.minutes.ago
    end, user_stat.new_since].max
  end

  def readable_name
    return "#{name} (#{username})" if name.present? && name != username
    username
  end

  def bio_summary
    return nil unless bio_cooked.present?
    Summarize.new(bio_cooked).summary
  end

  def badge_count
    user_badges.count
  end

  def featured_user_badges
    user_badges.joins(:badge).order('badges.badge_type_id ASC, badges.grant_count ASC').includes(:user, :granted_by, badge: :badge_type).limit(3)
  end

  def self.count_by_signup_date(sinceDaysAgo=30)
    where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end


  def secure_category_ids
    cats = self.admin? ? Category.where(read_restricted: true) : secure_categories.references(:categories)
    cats.pluck('categories.id').sort
  end

  def topic_create_allowed_category_ids
    Category.topic_create_allowed(self.id).select(:id)
  end


  # Flag all posts from a user as spam
  def flag_linked_posts_as_spam
    admin = Discourse.system_user
    topic_links.includes(:post).each do |tl|
      begin
        PostAction.act(admin, tl.post, PostActionType.types[:spam], message: I18n.t('flag_reason.spam_hosts'))
      rescue PostAction::AlreadyActed
        # If the user has already acted, just ignore it
      end
    end
  end

  def has_uploaded_avatar
    uploaded_avatar.present?
  end

  def added_a_day_ago?
    created_at > 1.day.ago
  end

  def upload_avatar(upload)
    self.uploaded_avatar_template = nil
    self.uploaded_avatar = upload
    self.use_uploaded_avatar = true
    self.save!
  end

  def upload_profile_background(upload)
    self.profile_background = upload.url
    self.save!
  end

  def generate_api_key(created_by)
    if api_key.present?
      api_key.regenerate!(created_by)
      api_key
    else
      ApiKey.create(user: self, key: SecureRandom.hex(32), created_by: created_by)
    end
  end

  def revoke_api_key
    ApiKey.where(user_id: self.id).delete_all
  end

  def find_email
    last_sent_email_address || email
  end

  def leader_requirements
    @lq ||= LeaderRequirements.new(self)
  end

  def should_be_redirected_to_top
    redirected_to_top_reason.present?
  end

  def redirected_to_top_reason
    # redirect is enabled
    return unless SiteSetting.redirect_users_to_top_page
    # top must be in the top_menu
    return unless SiteSetting.top_menu =~ /top/i
    # there should be enough topics
    return unless SiteSetting.has_enough_topics_to_redirect_to_top

    if !seen_before? || (trust_level == 0 && !redirected_to_top_yet?)
      update_last_redirected_to_top!
      return I18n.t('redirected_to_top_reasons.new_user')
    elsif last_seen_at < 1.month.ago
      update_last_redirected_to_top!
      return I18n.t('redirected_to_top_reasons.not_seen_in_a_month')
    end

    # no reason
    nil
  end

  def redirected_to_top_yet?
    last_redirected_to_top_at.present?
  end

  def update_last_redirected_to_top!
    key = "user:#{id}:update_last_redirected_to_top"
    delay = SiteSetting.active_user_rate_limit_secs

    # only update last_redirected_to_top_at once every minute
    return unless $redis.setnx(key, "1")
    $redis.expire(key, delay)

    # delay the update
    Jobs.enqueue_in(delay / 2, :update_top_redirection, user_id: self.id, redirected_at: Time.zone.now)
  end

  protected

  def cook
    if bio_raw.present?
      self.bio_cooked = PrettyText.cook(bio_raw, omit_nofollow: self.has_trust_level?(:leader)) if bio_raw_changed?
    else
      self.bio_cooked = nil
    end
  end

  def update_tracked_topics
    return unless auto_track_topics_after_msecs_changed?
    TrackedTopicsUpdater.new(id, auto_track_topics_after_msecs).call
  end

  def clear_global_notice_if_needed
    if admin && SiteSetting.has_login_hint
      SiteSetting.has_login_hint = false
      SiteSetting.global_notice = ""
    end
  end

  def create_user_stat
    stat = UserStat.new(new_since: Time.now)
    stat.user_id = id
    stat.save!
  end

  def create_email_token
    email_tokens.create(email: email)
  end

  def create_visit_record!(date, posts_read=0)
    user_stat.update_column(:days_visited, user_stat.days_visited + 1)
    user_visits.create!(visited_at: date, posts_read: posts_read)
  end

  def ensure_password_is_hashed
    if @raw_password
      self.salt = SecureRandom.hex(16)
      self.password_hash = hash_password(@raw_password, salt)
    end
  end

  def hash_password(password, salt)
    Pbkdf2.hash_password(password, salt, Rails.configuration.pbkdf2_iterations, Rails.configuration.pbkdf2_algorithm)
  end

  def add_trust_level
    # there is a possibility we did not load trust level column, skip it
    return unless has_attribute? :trust_level
    self.trust_level ||= SiteSetting.default_trust_level
  end

  def update_username_lower
    self.username_lower = username.downcase
  end

  def username_validator
    username_format_validator || begin
      lower = username.downcase
      existing = User.find_by(username_lower: lower)
      if username_changed? && existing && existing.id != self.id
        errors.add(:username, I18n.t(:'user.username.unique'))
      end
    end
  end

  def send_approval_email
    Jobs.enqueue(:user_email,
      type: :signup_after_approval,
      user_id: id,
      email_token: email_tokens.first.token
    )
  end

  def set_default_email_digest
    if has_attribute?(:email_digests) && self.email_digests.nil?
      if SiteSetting.default_digest_email_frequency.blank?
        self.email_digests = false
      else
        self.email_digests = true
        self.digest_after_days ||= SiteSetting.default_digest_email_frequency.to_i if has_attribute?(:digest_after_days)
      end
    end
  end

  def set_default_external_links_in_new_tab
    if has_attribute?(:external_links_in_new_tab) && self.external_links_in_new_tab.nil?
      self.external_links_in_new_tab = !SiteSetting.default_external_links_in_new_tab.blank?
    end
  end

  private

  def previous_visit_at_update_required?(timestamp)
    seen_before? && (last_seen_at < (timestamp - SiteSetting.previous_visit_timeout_hours.hours))
  end

  def update_previous_visit(timestamp)
    update_visit_record!(timestamp.to_date)
    if previous_visit_at_update_required?(timestamp)
      update_column(:previous_visit_at, last_seen_at)
    end
  end

end

# == Schema Information
#
# Table name: users
#
#  id                            :integer          not null, primary key
#  username                      :string(60)       not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  name                          :string(255)
#  bio_raw                       :text
#  seen_notification_id          :integer          default(0), not null
#  last_posted_at                :datetime
#  email                         :string(256)      not null
#  password_hash                 :string(64)
#  salt                          :string(32)
#  active                        :boolean
#  username_lower                :string(60)       not null
#  auth_token                    :string(32)
#  last_seen_at                  :datetime
#  website                       :string(255)
#  admin                         :boolean          default(FALSE), not null
#  last_emailed_at               :datetime
#  email_digests                 :boolean          not null
#  trust_level                   :integer          not null
#  bio_cooked                    :text
#  email_private_messages        :boolean          default(TRUE)
#  email_direct                  :boolean          default(TRUE), not null
#  approved                      :boolean          default(FALSE), not null
#  approved_by_id                :integer
#  approved_at                   :datetime
#  digest_after_days             :integer
#  previous_visit_at             :datetime
#  suspended_at                  :datetime
#  suspended_till                :datetime
#  date_of_birth                 :date
#  auto_track_topics_after_msecs :integer
#  views                         :integer          default(0), not null
#  flag_level                    :integer          default(0), not null
#  ip_address                    :inet
#  new_topic_duration_minutes    :integer
#  external_links_in_new_tab     :boolean          not null
#  enable_quoting                :boolean          default(TRUE), not null
#  moderator                     :boolean          default(FALSE)
#  blocked                       :boolean          default(FALSE)
#  dynamic_favicon               :boolean          default(FALSE), not null
#  title                         :string(255)
#  use_uploaded_avatar           :boolean          default(FALSE)
#  uploaded_avatar_template      :string(255)
#  uploaded_avatar_id            :integer
#  email_always                  :boolean          default(FALSE), not null
#  mailing_list_mode             :boolean          default(FALSE), not null
#  primary_group_id              :integer
#  locale                        :string(10)
#  profile_background            :string(255)
#  email_hash                    :string(255)
#  registration_ip_address       :inet
#  last_redirected_to_top_at     :datetime
#
# Indexes
#
#  index_users_on_auth_token      (auth_token)
#  index_users_on_email           (email) UNIQUE
#  index_users_on_last_posted_at  (last_posted_at)
#  index_users_on_username        (username) UNIQUE
#  index_users_on_username_lower  (username_lower) UNIQUE
#
