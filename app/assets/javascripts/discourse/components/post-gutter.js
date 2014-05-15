var MAX_SHOWN = 5;

Discourse.PostGutterComponent = Em.Component.extend({
  classNameBindings: [':span5', ':gutter'],

  // Roll up links to avoid duplicates
  collapsed: function() {
    var seen = {},
        result = [],
        links = this.get('links');

    if (!Em.isEmpty(links)) {
      links.forEach(function(l) {
        var title = Em.get(l, 'title');
        if (!seen[title]) {
          result.pushObject(l);
          seen[title] = true;
        }
      });
    }
    return result;
  }.property('links'),

  render: function(buffer) {
    var links = this.get('collapsed'),
        toRender = links,
        collapsed = !this.get('expanded');

    if (!Em.isEmpty(links)) {
      if (collapsed) {
        toRender = toRender.slice(0, MAX_SHOWN);
      }

      buffer.push("<ul class='post-links'>");
      toRender.forEach(function(l) {
        var direction = Em.get(l, 'reflection') ? 'left' : 'right',
            clicks = Em.get(l, 'clicks');

        buffer.push("<li><a href='" + Em.get(l, 'url') + "' class='track-link'>");
        buffer.push("<i class='fa fa-arrow-" + direction + "'></i>");
        buffer.push(Em.get(l, 'title'));
        if (clicks) {
          buffer.push("<span class='badge badge-notification clicks'>" + clicks + "</span>");
        }
        buffer.push("</a></li>");
      });

      if (collapsed) {
        var remaining = links.length - MAX_SHOWN;
        if (remaining > 0) {
          buffer.push("<li><a href='#' class='toggle-more'>" + I18n.t('post.more_links', {count: remaining}) + "</a></li>");
        }
      }
      buffer.push('</ul>');
    }

    if ((links.length <= MAX_SHOWN || !collapsed) && this.get('canReplyAsNewTopic')) {
      buffer.push("<a href='#' class='reply-new'><i class='fa fa-plus'></i>" + I18n.t('post.reply_as_new_topic') + "</a>");
    }
  },

  _rerenderIfNeeded: function() {
    this.rerender();
  }.observes('expanded'),

  click: function(e) {
    var $target = $(e.target);
    if ($target.hasClass('toggle-more')) {
      this.toggleProperty('expanded');
      return false;
    } else if ($target.hasClass('reply-new')) {
      this.sendAction('newTopicAction', this.get('post'));
      return false;
    }
    return true;
  }
});
