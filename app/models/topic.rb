require_dependency 'slug'
require_dependency 'avatar_lookup'
require_dependency 'topic_view'
require_dependency 'rate_limiter'
require_dependency 'text_sentinel'
require_dependency 'text_cleaner'
require_dependency 'archetype'

class Topic < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  include RateLimiter::OnCreateRecord
  include HasCustomFields
  include Trashable
  extend Forwardable

  def_delegator :featured_users, :user_ids, :featured_user_ids
  def_delegator :featured_users, :choose, :feature_topic_users

  def_delegator :notifier, :watch!, :notify_watch!
  def_delegator :notifier, :tracking!, :notify_tracking!
  def_delegator :notifier, :regular!, :notify_regular!
  def_delegator :notifier, :muted!, :notify_muted!
  def_delegator :notifier, :toggle_mute, :toggle_mute

  attr_accessor :allowed_user_ids

  def self.max_sort_order
    2**31 - 1
  end

  def featured_users
    @featured_users ||= TopicFeaturedUsers.new(self)
  end

  def trash!(trashed_by=nil)
    update_category_topic_count_by(-1) if deleted_at.nil?
    super(trashed_by)
    update_flagged_posts_count
  end

  def recover!
    update_category_topic_count_by(1) unless deleted_at.nil?
    super
    update_flagged_posts_count
  end

  rate_limit :default_rate_limiter
  rate_limit :limit_topics_per_day
  rate_limit :limit_private_messages_per_day

  validates :title, :presence => true,
                    :topic_title_length => true,
                    :quality_title => { :unless => :private_message? },
                    :unique_among  => { :unless => Proc.new { |t| (SiteSetting.allow_duplicate_topic_titles? || t.private_message?) },
                                        :message => :has_already_been_used,
                                        :allow_blank => true,
                                        :case_sensitive => false,
                                        :collection => Proc.new{ Topic.listable_topics } }

  validates :category_id,
            :presence => true,
            :exclusion => {
              :in => Proc.new{[SiteSetting.uncategorized_category_id]}
            },
            :if => Proc.new { |t|
                   (t.new_record? || t.category_id_changed?) &&
                   !SiteSetting.allow_uncategorized_topics &&
                   (t.archetype.nil? || t.archetype == Archetype.default) &&
                   (!t.user_id || !t.user.staff?)
            }


  before_validation do
    if SiteSetting.title_sanitize
      self.title = sanitize(title.to_s, tags: [], attributes: []).strip.presence
    end
    self.title = TextCleaner.clean_title(TextSentinel.title_sentinel(title).text) if errors[:title].empty?
  end

  belongs_to :category
  has_many :posts
  has_many :topic_allowed_users
  has_many :topic_allowed_groups

  has_many :allowed_group_users, through: :allowed_groups, source: :users
  has_many :allowed_groups, through: :topic_allowed_groups, source: :group
  has_many :allowed_users, through: :topic_allowed_users, source: :user

  has_one :top_topic
  belongs_to :user
  belongs_to :last_poster, class_name: 'User', foreign_key: :last_post_user_id
  belongs_to :featured_user1, class_name: 'User', foreign_key: :featured_user1_id
  belongs_to :featured_user2, class_name: 'User', foreign_key: :featured_user2_id
  belongs_to :featured_user3, class_name: 'User', foreign_key: :featured_user3_id
  belongs_to :featured_user4, class_name: 'User', foreign_key: :featured_user4_id
  belongs_to :auto_close_user, class_name: 'User', foreign_key: :auto_close_user_id

  has_many :topic_users
  has_many :topic_links
  has_many :topic_invites
  has_many :invites, through: :topic_invites, source: :invite

  has_many :revisions, foreign_key: :topic_id, class_name: 'TopicRevision'

  # When we want to temporarily attach some data to a forum topic (usually before serialization)
  attr_accessor :user_data
  attr_accessor :posters  # TODO: can replace with posters_summary once we remove old list code
  attr_accessor :participants
  attr_accessor :topic_list
  attr_accessor :meta_data
  attr_accessor :include_last_poster

  # The regular order
  scope :topic_list_order, -> { order('topics.bumped_at desc') }

  # Return private message topics
  scope :private_messages, -> { where(archetype: Archetype.private_message) }

  scope :listable_topics, -> { where('topics.archetype <> ?', [Archetype.private_message]) }

  scope :by_newest, -> { order('topics.created_at desc, topics.id desc') }

  scope :visible, -> { where(visible: true) }

  scope :created_since, lambda { |time_ago| where('created_at > ?', time_ago) }

  scope :secured, lambda { |guardian=nil|
    ids = guardian.secure_category_ids if guardian

    # Query conditions
    condition = if ids.present?
      ["NOT c.read_restricted or c.id in (:cats)", cats: ids]
    else
      ["NOT c.read_restricted"]
    end

    where("category_id IS NULL OR category_id IN (
           SELECT c.id FROM categories c
           WHERE #{condition[0]})", condition[1])
  }

  # Helps us limit how many topics can be starred in a day
  class StarLimiter < RateLimiter
    def initialize(user)
      super(user, "starred:#{Date.today.to_s}", SiteSetting.max_stars_per_day, 1.day.to_i)
    end
  end

  before_create do
    self.bumped_at ||= Time.now
    self.last_post_user_id ||= user_id
    if !@ignore_category_auto_close and self.category and self.category.auto_close_hours and self.auto_close_at.nil?
      set_auto_close(self.category.auto_close_hours)
    end
  end

  attr_accessor :skip_callbacks

  after_create do

    unless skip_callbacks
      changed_to_category(category)
      if archetype == Archetype.private_message
        DraftSequence.next!(user, Draft::NEW_PRIVATE_MESSAGE)
      else
        DraftSequence.next!(user, Draft::NEW_TOPIC)
      end
    end

  end

  before_save do

    unless skip_callbacks
      if (auto_close_at_changed? and !auto_close_at_was.nil?) or (auto_close_user_id_changed? and auto_close_at)
        self.auto_close_started_at ||= Time.zone.now if auto_close_at
        Jobs.cancel_scheduled_job(:close_topic, {topic_id: id})
        true
      end
      if category_id.nil? && (archetype.nil? || archetype == Archetype.default)
        self.category_id = SiteSetting.uncategorized_category_id
      end
    end

  end

  after_save do
    save_revision if should_create_new_version?

    unless skip_callbacks
      if auto_close_at and (auto_close_at_changed? or auto_close_user_id_changed?)
        Jobs.enqueue_at(auto_close_at, :close_topic, {topic_id: id, user_id: auto_close_user_id || user_id})
      end
    end

  end

  # TODO move into PostRevisor or TopicRevisor
  def save_revision
    if first_post_id = posts.where(post_number: 1).pluck(:id).first

      number = PostRevision.where(post_id: first_post_id).count + 2
      PostRevision.create!(
        user_id: acting_user.id,
        post_id: first_post_id,
        number: number,
        modifications: changes.extract!(:category_id, :title)
      )

      Post.where(id: first_post_id).update_all(version: number)
    end
  end

  def should_create_new_version?
    !new_record? && (category_id_changed? || title_changed?)
  end

  def self.top_viewed(max = 10)
    Topic.listable_topics.visible.secured.order('views desc').limit(max)
  end

  def self.recent(max = 10)
    Topic.listable_topics.visible.secured.order('created_at desc').limit(max)
  end

  def self.count_exceeds_minimum?
    count > SiteSetting.minimum_topics_similar
  end

  def best_post
    posts.order('score desc').limit(1).first
  end

  # all users (in groups or directly targetted) that are going to get the pm
  def all_allowed_users
    # TODO we should probably change this from 3 queries to 1
    User.where('id in (?)', allowed_users.select('users.id').to_a + allowed_group_users.select('users.id').to_a)
  end

  # Additional rate limits on topics: per day and private messages per day
  def limit_topics_per_day
    apply_per_day_rate_limit_for("topics", :max_topics_per_day)
    limit_first_day_topics_per_day if user.added_a_day_ago?
  end

  def limit_private_messages_per_day
    return unless private_message?
    apply_per_day_rate_limit_for("pms", :max_private_messages_per_day)
  end

  def fancy_title
    sanitized_title = if SiteSetting.title_sanitize
      sanitize(title.to_s, tags: [], attributes: []).strip.presence
    else
      title.gsub(/['&\"<>]/, {
        "'" => '&#39;',
        '&' => '&amp;',
        '"' => '&quot;',
        '<' => '&lt;',
        '>' => '&gt;',
      })
    end

    return unless sanitized_title
    return sanitized_title unless SiteSetting.title_fancy_entities?

    # We don't always have to require this, if fancy is disabled
    # see: http://meta.discourse.org/t/pattern-for-defer-loading-gems-and-profiling-with-perftools-rb/4629
    require 'redcarpet' unless defined? Redcarpet

    Redcarpet::Render::SmartyPants.render(sanitized_title)
  end

  def new_version_required?
    title_changed? || category_id_changed?
  end

  # Returns hot topics since a date for display in email digest.
  def self.for_digest(user, since, opts=nil)
    opts = opts || {}
    score = "#{ListController.best_period_for(since)}_score"

    topics = Topic
              .visible
              .secured(Guardian.new(user))
              .joins("LEFT OUTER JOIN topic_users ON topic_users.topic_id = topics.id AND topic_users.user_id = #{user.id.to_i}")
              .where(closed: false, archived: false)
              .where("COALESCE(topic_users.notification_level, 1) <> ?", TopicUser.notification_levels[:muted])
              .created_since(since)
              .listable_topics
              .includes(:category)

    if !!opts[:top_order]
      topics = topics.joins("LEFT OUTER JOIN top_topics ON top_topics.topic_id = topics.id")
                     .order(TopicQuerySQL.order_top_for(score))
    end

    if opts[:limit]
      topics = topics.limit(opts[:limit])
    end

    # Remove category topics
    category_topic_ids = Category.pluck(:topic_id).compact!
    if category_topic_ids.present?
      topics = topics.where("topics.id NOT IN (?)", category_topic_ids)
    end

    # Remove muted categories
    muted_category_ids = CategoryUser.where(user_id: user.id, notification_level: CategoryUser.notification_levels[:muted]).pluck(:category_id)
    if muted_category_ids.present?
      topics = topics.where("topics.category_id NOT IN (?)", muted_category_ids)
    end

    topics
  end

  # Using the digest query, figure out what's  new for a user since last seen
  def self.new_since_last_seen(user, since, featured_topic_ids)
    topics = Topic.for_digest(user, since)
    topics.where("topics.id NOT IN (?)", featured_topic_ids)
  end

  def meta_data=(data)
    custom_fields.replace(data)
  end

  def meta_data
    custom_fields
  end

  def update_meta_data(data)
    custom_fields.update(data)
    save
  end

  def reload(options=nil)
    @post_numbers = nil
    super(options)
  end

  def post_numbers
    @post_numbers ||= posts.order(:post_number).pluck(:post_number)
  end

  def age_in_minutes
    ((Time.zone.now - created_at) / 1.minute).round
  end

  def has_meta_data_boolean?(key)
    meta_data_string(key) == 'true'
  end

  def meta_data_string(key)
    custom_fields[key.to_s]
  end

  def self.listable_count_per_day(sinceDaysAgo=30)
    listable_topics.where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end

  def private_message?
    archetype == Archetype.private_message
  end

  # Search for similar topics
  def self.similar_to(title, raw, user=nil)
    return [] unless title.present?
    return [] unless raw.present?

    similar = Topic.select(sanitize_sql_array(["topics.*, similarity(topics.title, :title) + similarity(p.raw, :raw) AS similarity", title: title, raw: raw]))
                     .visible
                     .where(closed: false, archived: false)
                     .secured(Guardian.new(user))
                     .listable_topics
                     .joins("LEFT OUTER JOIN posts AS p ON p.topic_id = topics.id AND p.post_number = 1")
                     .limit(SiteSetting.max_similar_results)
                     .order('similarity desc')

    # Exclude category definitions from similar topic suggestions
    exclude_topic_ids = Category.pluck(:topic_id).compact!
    if exclude_topic_ids.present?
      similar = similar.where("topics.id NOT IN (?)", exclude_topic_ids)
    end

    similar
  end

  def update_status(status, enabled, user)
    TopicStatusUpdate.new(self, user).update! status, enabled
  end

  # Atomically creates the next post number
  def self.next_post_number(topic_id, reply = false)
    highest = exec_sql("select coalesce(max(post_number),0) as max from posts where topic_id = ?", topic_id).first['max'].to_i

    reply_sql = reply ? ", reply_count = reply_count + 1" : ""
    result = exec_sql("UPDATE topics SET highest_post_number = ? + 1#{reply_sql}
                       WHERE id = ? RETURNING highest_post_number", highest, topic_id)
    result.first['highest_post_number'].to_i
  end

  # If a post is deleted we have to update our highest post counters
  def self.reset_highest(topic_id)
    result = exec_sql "UPDATE topics
                        SET highest_post_number = (SELECT COALESCE(MAX(post_number), 0) FROM posts WHERE topic_id = :topic_id AND deleted_at IS NULL),
                            posts_count = (SELECT count(*) FROM posts WHERE deleted_at IS NULL AND topic_id = :topic_id),
                            last_posted_at = (SELECT MAX(created_at) FROM POSTS WHERE topic_id = :topic_id AND deleted_at IS NULL)
                        WHERE id = :topic_id
                        RETURNING highest_post_number", topic_id: topic_id
    highest_post_number = result.first['highest_post_number'].to_i

    # Update the forum topic user records
    exec_sql "UPDATE topic_users
              SET last_read_post_number = CASE
                                          WHEN last_read_post_number > :highest THEN :highest
                                          ELSE last_read_post_number
                                          END,
                  seen_post_count = CASE
                                    WHEN seen_post_count > :highest THEN :highest
                                    ELSE seen_post_count
                                    END
              WHERE topic_id = :topic_id",
              highest: highest_post_number,
              topic_id: topic_id
  end

  # This calculates the geometric mean of the posts and stores it with the topic
  def self.calculate_avg_time(min_topic_age=nil)
    builder = SqlBuilder.new("UPDATE topics
              SET avg_time = x.gmean
              FROM (SELECT topic_id,
                           round(exp(avg(ln(avg_time)))) AS gmean
                    FROM posts
                    WHERE avg_time > 0 AND avg_time IS NOT NULL
                    GROUP BY topic_id) AS x
              /*where*/")

    builder.where("x.topic_id = topics.id AND
                  (topics.avg_time <> x.gmean OR topics.avg_time IS NULL)")

    if min_topic_age
      builder.where("topics.bumped_at > :bumped_at",
                   bumped_at: min_topic_age)
    end

    builder.exec
  end

  def changed_to_category(cat)
    return true if cat.blank? || Category.find_by(topic_id: id).present?

    Topic.transaction do
      old_category = category

      if category_id.present? && category_id != cat.id
        Category.where(['id = ?', category_id]).update_all 'topic_count = topic_count - 1'
      end

      success = true
      if self.category_id != cat.id
        self.category_id = cat.id
        success = save
      end

      if success
        CategoryFeaturedTopic.feature_topics_for(old_category)
        Category.where(id: cat.id).update_all 'topic_count = topic_count + 1'
        CategoryFeaturedTopic.feature_topics_for(cat) unless old_category.try(:id) == cat.try(:id)
      else
        return false
      end
    end
    true
  end

  def add_moderator_post(user, text, opts={})
    new_post = nil
    Topic.transaction do
      creator = PostCreator.new(user,
                                raw: text,
                                post_type: Post.types[:moderator_action],
                                no_bump: opts[:bump].blank?,
                                topic_id: self.id)
      new_post = creator.create
      increment!(:moderator_posts_count)
      new_post
    end

    if new_post.present?
      # If we are moving posts, we want to insert the moderator post where the previous posts were
      # in the stream, not at the end.
      new_post.update_attributes(post_number: opts[:post_number], sort_order: opts[:post_number]) if opts[:post_number].present?

      # Grab any links that are present
      TopicLink.extract_from(new_post)
    end

    new_post
  end

  # Changes the category to a new name
  def change_category(name)
    # If the category name is blank, reset the attribute
    if name.blank?
      cat = Category.find_by(id: SiteSetting.uncategorized_category_id)
    else
      cat = Category.find_by(name: name)
    end

    return true if cat == category
    return false unless cat
    changed_to_category(cat)
  end


  def remove_allowed_user(username)
    user = User.find_by(username: username)
    if user
      topic_user = topic_allowed_users.find_by(user_id: user.id)
      if topic_user
        topic_user.destroy
      else
        false
      end
    end
  end

  # Invite a user to the topic by username or email. Returns success/failure
  def invite(invited_by, username_or_email, group_ids=nil)
    if private_message?
      # If the user exists, add them to the topic.
      user = User.find_by_username_or_email(username_or_email)
      if user && topic_allowed_users.create!(user_id: user.id)

        # Notify the user they've been invited
        user.notifications.create(notification_type: Notification.types[:invited_to_private_message],
                                  topic_id: id,
                                  post_number: 1,
                                  data: { topic_title: title,
                                          display_username: invited_by.username }.to_json)
        return true
      end
    end

    if username_or_email =~ /^.+@.+$/
      # NOTE callers expect an invite object if an invite was sent via email
      invite_by_email(invited_by, username_or_email, group_ids)
    else
      false
    end
  end

  def invite_by_email(invited_by, email, group_ids=nil)
    Invite.invite_by_email(email, invited_by, self, group_ids)
  end

  def email_already_exists_for?(invite)
    invite.email_already_exists and private_message?
  end

  def grant_permission_to_user(lower_email)
    user = User.find_by(email: lower_email)
    topic_allowed_users.create!(user_id: user.id)
  end

  def max_post_number
    posts.maximum(:post_number).to_i
  end

  def move_posts(moved_by, post_ids, opts)
    post_mover = PostMover.new(self, moved_by, post_ids)

    if opts[:destination_topic_id]
      post_mover.to_topic opts[:destination_topic_id]
    elsif opts[:title]
      post_mover.to_new_topic(opts[:title], opts[:category_id])
    end
  end

  # Updates the denormalized statistics of a topic including featured posters. They shouldn't
  # go out of sync unless you do something drastic live move posts from one topic to another.
  # this recalculates everything.
  def update_statistics
    feature_topic_users
    update_action_counts
    Topic.reset_highest(id)
  end

  def update_flagged_posts_count
    PostAction.update_flagged_posts_count
  end

  def update_action_counts
    PostActionType.types.keys.each do |type|
      count_field = "#{type}_count"
      update_column(count_field, Post.where(topic_id: id).sum(count_field))
    end
  end

  def posters_summary(options = {})
    @posters_summary ||= TopicPostersSummary.new(self, options).summary
  end

  def participants_summary(options = {})
    @participants_summary ||= TopicParticipantsSummary.new(self, options).summary
  end

  # Enable/disable the star on the topic
  def toggle_star(user, starred)
    Topic.transaction do
      TopicUser.change(user, id, {starred: starred}.merge( starred ? {starred_at: DateTime.now, unstarred_at: nil} : {unstarred_at: DateTime.now}))

      # Update the star count
      exec_sql "UPDATE topics
                SET star_count = (SELECT COUNT(*)
                                  FROM topic_users AS ftu
                                  WHERE ftu.topic_id = topics.id
                                    AND ftu.starred = true)
                WHERE id = ?", id

      if starred
        StarLimiter.new(user).performed!
      else
        StarLimiter.new(user).rollback!
      end
    end
  end

  def self.starred_counts_per_day(sinceDaysAgo=30)
    TopicUser.starred_since(sinceDaysAgo).by_date_starred.count
  end

  # Even if the slug column in the database is null, topic.slug will return something:
  def slug
    unless slug = read_attribute(:slug)
      return '' unless title.present?
      slug = Slug.for(title).presence || "topic"
      if new_record?
        write_attribute(:slug, slug)
      else
        update_column(:slug, slug)
      end
    end

    slug
  end

  def title=(t)
    slug = (Slug.for(t.to_s).presence || "topic")
    write_attribute(:slug, slug)
    write_attribute(:title,t)
  end

  # NOTE: These are probably better off somewhere else.
  #       Having a model know about URLs seems a bit strange.
  def last_post_url
    "/t/#{slug}/#{id}/#{posts_count}"
  end

  def self.url(id, slug, post_number=nil)
    url = "#{Discourse.base_url}/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def url(post_number = nil)
    self.class.url id, slug, post_number
  end

  def relative_url(post_number=nil)
    url = "/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def clear_pin_for(user)
    return unless user.present?
    TopicUser.change(user.id, id, cleared_pinned_at: Time.now)
  end

  def re_pin_for(user)
    return unless user.present?
    TopicUser.change(user.id, id, cleared_pinned_at: nil)
  end

  def update_pinned(status, global=false)
    update_column(:pinned_at, status ? Time.now : nil)
    update_column(:pinned_globally, global)
  end

  def draft_key
    "#{Draft::EXISTING_TOPIC}#{id}"
  end

  def notifier
    @topic_notifier ||= TopicNotifier.new(self)
  end

  def muted?(user)
    if user && user.id
      notifier.muted?(user.id)
    end
  end

  def auto_close_hours=(num_hours)
    @ignore_category_auto_close = true
    set_auto_close( num_hours )
  end

  def self.auto_close
    Topic.where("NOT closed AND auto_close_at < ? AND auto_close_user_id IS NOT NULL", 1.minute.ago).each do |t|
      t.auto_close
    end
  end

  def auto_close(closer = nil)
    if auto_close_at && !closed? && !deleted_at && auto_close_at < 5.minutes.from_now
      closer ||= auto_close_user
      if Guardian.new(closer).can_moderate?(self)
        update_status('autoclosed', true, closer)
      end
    end
  end

  # Valid arguments for the auto close time:
  #  * An integer, which is the number of hours from now to close the topic.
  #  * A time, like "12:00", which is the time at which the topic will close in the current day
  #    or the next day if that time has already passed today.
  #  * A timestamp, like "2013-11-25 13:00", when the topic should close.
  #  * A timestamp with timezone in JSON format. (e.g., "2013-11-26T21:00:00.000Z")
  #  * nil, to prevent the topic from automatically closing.
  def set_auto_close(arg, by_user=nil)
    if arg.is_a?(String) && matches = /^([\d]{1,2}):([\d]{1,2})$/.match(arg.strip)
      now = Time.zone.now
      self.auto_close_at = Time.zone.local(now.year, now.month, now.day, matches[1].to_i, matches[2].to_i)
      self.auto_close_at += 1.day if self.auto_close_at < now
    elsif arg.is_a?(String) && arg.include?('-') && timestamp = Time.zone.parse(arg)
      self.auto_close_at = timestamp
      self.errors.add(:auto_close_at, :invalid) if timestamp < Time.zone.now
    else
      num_hours = arg.to_i
      self.auto_close_at = (num_hours > 0 ? num_hours.hours.from_now : nil)
    end

    unless self.auto_close_at.nil?
      self.auto_close_started_at ||= Time.zone.now
      if by_user && by_user.staff?
        self.auto_close_user = by_user
      else
        self.auto_close_user ||= (self.user.staff? ? self.user : Discourse.system_user)
      end
    else
      self.auto_close_started_at = nil
    end
    self
  end

  def read_restricted_category?
    category && category.read_restricted
  end

  def acting_user
    @acting_user || user
  end

  def acting_user=(u)
    @acting_user = u
  end

  def secure_group_ids
    @secure_group_ids ||= if self.category && self.category.read_restricted?
      self.category.secure_group_ids
    end
  end

  def has_topic_embed?
    TopicEmbed.where(topic_id: id).exists?
  end

  def expandable_first_post?
    SiteSetting.embeddable_host.present? && SiteSetting.embed_truncate? && has_topic_embed?
  end

  private

  def update_category_topic_count_by(num)
    if category_id.present?
      Category.where(['id = ?', category_id]).update_all("topic_count = topic_count " + (num > 0 ? '+' : '') + "#{num}")
    end
  end

  def limit_first_day_topics_per_day
    apply_per_day_rate_limit_for("first-day-topics", :max_topics_in_first_day)
  end

  def apply_per_day_rate_limit_for(key, method_name)
    RateLimiter.new(user, "#{key}-per-day:#{Date.today.to_s}", SiteSetting.send(method_name), 1.day.to_i)
  end

end

# == Schema Information
#
# Table name: topics
#
#  id                      :integer          not null, primary key
#  title                   :string(255)      not null
#  last_posted_at          :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  views                   :integer          default(0), not null
#  posts_count             :integer          default(0), not null
#  user_id                 :integer
#  last_post_user_id       :integer          not null
#  reply_count             :integer          default(0), not null
#  featured_user1_id       :integer
#  featured_user2_id       :integer
#  featured_user3_id       :integer
#  avg_time                :integer
#  deleted_at              :datetime
#  highest_post_number     :integer          default(0), not null
#  image_url               :string(255)
#  off_topic_count         :integer          default(0), not null
#  like_count              :integer          default(0), not null
#  incoming_link_count     :integer          default(0), not null
#  bookmark_count          :integer          default(0), not null
#  star_count              :integer          default(0), not null
#  category_id             :integer
#  visible                 :boolean          default(TRUE), not null
#  moderator_posts_count   :integer          default(0), not null
#  closed                  :boolean          default(FALSE), not null
#  archived                :boolean          default(FALSE), not null
#  bumped_at               :datetime         not null
#  has_summary             :boolean          default(FALSE), not null
#  vote_count              :integer          default(0), not null
#  archetype               :string(255)      default("regular"), not null
#  featured_user4_id       :integer
#  notify_moderators_count :integer          default(0), not null
#  spam_count              :integer          default(0), not null
#  illegal_count           :integer          default(0), not null
#  inappropriate_count     :integer          default(0), not null
#  pinned_at               :datetime
#  score                   :float
#  percent_rank            :float            default(1.0), not null
#  notify_user_count       :integer          default(0), not null
#  subtype                 :string(255)
#  slug                    :string(255)
#  auto_close_at           :datetime
#  auto_close_user_id      :integer
#  auto_close_started_at   :datetime
#  deleted_by_id           :integer
#  participant_count       :integer          default(1)
#  word_count              :integer
#  excerpt                 :string(1000)
#  pinned_globally         :boolean          default(FALSE), not null
#
# Indexes
#
#  idx_topics_front_page              (deleted_at,visible,archetype,category_id,id)
#  idx_topics_user_id_deleted_at      (user_id)
#  index_forum_threads_on_bumped_at   (bumped_at)
#  index_topics_on_id_and_deleted_at  (id,deleted_at)
#
