# Responsible for destroying a User record
class UserDestroyer

  class PostsExistError < RuntimeError; end

  def initialize(actor)
    @actor = actor
    raise Discourse::InvalidParameters.new('acting user is nil') unless @actor and @actor.is_a?(User)
    @guardian = Guardian.new(actor)
  end

  # Returns false if the user failed to be deleted.
  # Returns a frozen instance of the User if the delete succeeded.
  def destroy(user, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user and user.is_a?(User)
    @guardian.ensure_can_delete_user!(user)
    raise PostsExistError if !opts[:delete_posts] && user.post_count != 0
    User.transaction do
      if opts[:delete_posts]
        user.posts.each do |post|
          if opts[:block_urls]
            post.topic_links.each do |link|
              unless link.internal or Oneboxer.oneboxer_exists_for_url?(link.url)
                ScreenedUrl.watch(link.url, link.domain, ip_address: user.ip_address).try(:record_match!)
              end
            end
          end
          PostDestroyer.new(@actor.staff? ? @actor : Discourse.system_user, post).destroy
          if post.topic and post.post_number == 1
            Topic.unscoped.where(id: post.topic.id).update_all(user_id: nil)
          end
        end
      end
      user.post_actions.each do |post_action|
        post_action.remove_act!(Discourse.system_user)
      end
      user.destroy.tap do |u|
        if u
          if opts[:block_email]
            b = ScreenedEmail.block(u.email, ip_address: u.ip_address)
            b.record_match! if b
          end
          if opts[:block_ip] && u.ip_address
            b.record_match! if b = ScreenedIpAddress.watch(u.ip_address)
            if u.registration_ip_address && u.ip_address != u.registration_ip_address
              b.record_match! if b = ScreenedIpAddress.watch(u.registration_ip_address)
            end
          end
          Post.with_deleted.where(user_id: user.id).update_all("user_id = NULL")

          # If this user created categories, fix those up:
          categories = Category.where(user_id: user.id)
          categories.each do |c|
            c.user_id = Discourse.system_user.id
            c.save!
            if topic = Topic.with_deleted.find_by(id: c.topic_id)
              topic.try(:recover!)
              topic.user_id = Discourse.system_user.id
              topic.save!
            end
          end

          StaffActionLogger.new(@actor == user ? Discourse.system_user : @actor).log_user_deletion(user, opts.slice(:context))
          DiscourseHub.unregister_username(user.username) if SiteSetting.call_discourse_hub?
          MessageBus.publish "/file-change", ["refresh"], user_ids: [user.id]
        end
      end
    end
  end

end
