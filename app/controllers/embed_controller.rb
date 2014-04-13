class EmbedController < ApplicationController
  skip_before_filter :check_xhr
  skip_before_filter :preload_json
  skip_before_filter :store_incoming_links

  before_filter :ensure_embeddable

  layout 'embed'

  def comments
    embed_url = params.require(:embed_url)
    topic_id = TopicEmbed.topic_id_for_embed(embed_url)

    if topic_id
      @topic_view = TopicView.new(topic_id, current_user, limit: SiteSetting.embed_post_limit, exclude_first: true)
      @second_post_url = "#{@topic_view.topic.url}/2" if @topic_view
      @posts_left = 0
      if @topic_view && @topic_view.posts.size == SiteSetting.embed_post_limit
        @posts_left = @topic_view.topic.posts_count - SiteSetting.embed_post_limit
      end
    else
      Jobs.enqueue(:retrieve_topic, user_id: current_user.try(:id), embed_url: embed_url)
      render 'loading'
    end

    discourse_expires_in 1.minute
  end

  def count

    urls = params[:embed_url].map {|u| u.sub(/#discourse-comments$/, '').sub(/\/$/, '') }
    topic_embeds = TopicEmbed.where(embed_url: urls).includes(:topic).references(:topic)

    by_url = {}
    topic_embeds.each do |te|
      url = te.embed_url 
      url = "#{url}#discourse-comments" unless params[:embed_url].include?(url)
      by_url[url] = I18n.t('embed.replies', count: te.topic.posts_count - 1)
    end

    respond_to do |format|
      format.js { render json: {counts: by_url}, callback: params[:callback] }
    end
  end

  private

    def ensure_embeddable

      if !(Rails.env.development? && current_user.try(:admin?))
        raise Discourse::InvalidAccess.new('embeddable host not set') if SiteSetting.normalized_embeddable_host.blank?
        raise Discourse::InvalidAccess.new('invalid referer host') if URI(request.referer || '').host != SiteSetting.normalized_embeddable_host
      end

      response.headers['X-Frame-Options'] = "ALLOWALL"
    rescue URI::InvalidURIError
      raise Discourse::InvalidAccess.new('invalid referer host')
    end


end
