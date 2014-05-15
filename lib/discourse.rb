require 'cache'
require_dependency 'plugin/instance'
require_dependency 'auth/default_current_user_provider'

module Discourse

  require 'sidekiq/exception_handler'
  class SidekiqExceptionHandler
    extend Sidekiq::ExceptionHandler
  end

  def self.handle_exception(ex, context=nil, parent_logger = nil)
    context ||= {}
    parent_logger ||= SidekiqExceptionHandler

    cm = RailsMultisite::ConnectionManagement
    parent_logger.handle_exception(ex, {
      current_db: cm.current_db,
      current_hostname: cm.current_hostname
    }.merge(context))
  end

  # Expected less matches than what we got in a find
  class TooManyMatches < Exception; end

  # When they try to do something they should be logged in for
  class NotLoggedIn < Exception; end

  # When the input is somehow bad
  class InvalidParameters < Exception; end

  # When they don't have permission to do something
  class InvalidAccess < Exception; end

  # When something they want is not found
  class NotFound < Exception; end

  # When a setting is missing
  class SiteSettingMissing < Exception; end

  # When ImageMagick is missing
  class ImageMagickMissing < Exception; end

  class InvalidPost < Exception; end

  # When read-only mode is enabled
  class ReadOnly < Exception; end

  # Cross site request forgery
  class CSRF < Exception; end

  def self.filters
    @filters ||= [:latest, :unread, :new, :starred, :read, :posted]
  end

  def self.anonymous_filters
    @anonymous_filters ||= [:latest]
  end

  def self.logged_in_filters
    @logged_in_filters ||= Discourse.filters - Discourse.anonymous_filters
  end

  def self.top_menu_items
    @top_menu_items ||= Discourse.filters + [:category, :categories, :top]
  end

  def self.anonymous_top_menu_items
    @anonymous_top_menu_items ||= Discourse.anonymous_filters + [:category, :categories, :top]
  end

  def self.activate_plugins!
    @plugins = Plugin::Instance.find_all("#{Rails.root}/plugins")
    @plugins.each { |plugin| plugin.activate! }
  end

  def self.plugins
    @plugins
  end

  def self.assets_digest
    @assets_digest ||= begin
      digest = Digest::MD5.hexdigest(ActionView::Base.assets_manifest.assets.values.sort.join)

      channel = "/global/asset-version"
      message = MessageBus.last_message(channel)

      unless message && message.data == digest
        MessageBus.publish channel, digest
      end
      digest
    end
  end

  def self.authenticators
    # TODO: perhaps we don't need auth providers and authenticators maybe one object is enough

    # NOTE: this bypasses the site settings and gives a list of everything, we need to register every middleware
    #  for the cases of multisite
    # In future we may change it so we don't include them all for cases where we are not a multisite, but we would
    #  require a restart after site settings change
    Users::OmniauthCallbacksController::BUILTIN_AUTH + auth_providers.map(&:authenticator)
  end

  def self.auth_providers
    providers = []
    if plugins
      plugins.each do |p|
        next unless p.auth_providers
        p.auth_providers.each do |prov|
          providers << prov
        end
      end
    end
    providers
  end

  def self.cache
    @cache ||= Cache.new
  end

  # Get the current base URL for the current site
  def self.current_hostname
    if SiteSetting.force_hostname.present?
      SiteSetting.force_hostname
    else
      RailsMultisite::ConnectionManagement.current_hostname
    end
  end

  def self.base_uri(default_value = "")
    if !ActionController::Base.config.relative_url_root.blank?
      ActionController::Base.config.relative_url_root
    else
      default_value
    end
  end

  def self.base_url_no_prefix
    default_port = 80
    protocol = "http"

    if SiteSetting.use_https?
      protocol = "https"
      default_port = 443
    end

    result = "#{protocol}://#{current_hostname}"

    port = SiteSetting.port.present? && SiteSetting.port.to_i > 0 ? SiteSetting.port.to_i : default_port

    result << ":#{SiteSetting.port}" if port != default_port
    result
  end

  def self.base_url
    return base_url_no_prefix + base_uri
  end

  def self.enable_readonly_mode
    $redis.set readonly_mode_key, 1
    MessageBus.publish(readonly_channel, true)
    true
  end

  def self.disable_readonly_mode
    $redis.del readonly_mode_key
    MessageBus.publish(readonly_channel, false)
    true
  end

  def self.readonly_mode?
    !!$redis.get(readonly_mode_key)
  end

  def self.request_refresh!
    # Causes refresh on next click for all clients
    #
    # This is better than `MessageBus.publish "/file-change", ["refresh"]` because
    # it spreads the refreshes out over a time period
    MessageBus.publish '/global/asset-version', 'clobber'
  end

  def self.git_version
    return $git_version if $git_version

    # load the version stamped by the "build:stamp" task
    f = Rails.root.to_s + "/config/version"
    require f if File.exists?("#{f}.rb")

    begin
      $git_version ||= `git rev-parse HEAD`.strip
    rescue
      $git_version = "unknown"
    end
  end

  # Either returns the site_contact_username user or the first admin.
  def self.site_contact_user
    user = User.find_by(username_lower: SiteSetting.site_contact_username.downcase) if SiteSetting.site_contact_username.present?
    user ||= User.admins.real.order(:id).first
  end

  def self.system_user
    User.find_by(id: -1)
  end

  def self.store
    if SiteSetting.enable_s3_uploads?
      @s3_store_loaded ||= require 'file_store/s3_store'
      FileStore::S3Store.new
    else
      @local_store_loaded ||= require 'file_store/local_store'
      FileStore::LocalStore.new
    end
  end

  def self.current_user_provider
    @current_user_provider || Auth::DefaultCurrentUserProvider
  end

  def self.current_user_provider=(val)
    @current_user_provider = val
  end

  def self.asset_host
    Rails.configuration.action_controller.asset_host
  end

  def self.readonly_mode_key
    "readonly_mode"
  end

  def self.readonly_channel
    "/site/read-only"
  end

  # all forking servers must call this
  # after fork, otherwise Discourse will be
  # in a bad state
  def self.after_fork
    current_db = RailsMultisite::ConnectionManagement.current_db
    RailsMultisite::ConnectionManagement.establish_connection(db: current_db)
    MessageBus.after_fork
    SiteSetting.after_fork
    $redis.client.reconnect
    Rails.cache.reconnect
    Logster.store.redis.reconnect
    # shuts down all connections in the pool
    Sidekiq.redis_pool.shutdown{|c| nil}
    # re-establish
    Sidekiq.redis = sidekiq_redis_config
    nil
  end

  def self.sidekiq_redis_config
    { url: $redis.url, namespace: 'sidekiq' }
  end

end
