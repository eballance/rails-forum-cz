/*global LockOn:true*/

/**
  This view is for rendering an icon representing the status of a topic

  @class TopicView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.Scrolling
  @module Discourse
**/
Discourse.TopicView = Discourse.View.extend(Discourse.Scrolling, {
  templateName: 'topic',
  topicBinding: 'controller.model',
  userFiltersBinding: 'controller.userFilters',
  classNameBindings: ['controller.multiSelect:multi-select',
                      'topic.archetype',
                      'topic.category.read_restricted:read_restricted',
                      'topic.deleted:deleted-topic'],
  menuVisible: true,
  SHORT_POST: 1200,

  postStream: Em.computed.alias('controller.postStream'),

  updateBar: function() {
    Em.run.scheduleOnce('afterRender', this, '_updateProgressBar');
  }.observes('controller.streamPercentage'),

  _updateProgressBar: function() {
    var $topicProgress = this._topicProgress;

    // cache lookup
    if (!$topicProgress) {
      $topicProgress = $('#topic-progress');
      if (!$topicProgress.length) {
        return;
      }
      this._topicProgress = $topicProgress;
    }

    // speeds up stuff, bypass jquery slowness and extra checks
    var totalWidth = $topicProgress[0].offsetWidth,
        progressWidth = this.get('controller.streamPercentage') * totalWidth;

    $topicProgress.find('.bg')
                  .css("border-right-width", (progressWidth === totalWidth) ? "0px" : "1px")
                  .width(progressWidth);
  },

  _updateTitle: function() {
    var title = this.get('topic.title');
    if (title) return Discourse.set('title', _.unescape(title));
  }.observes('topic.loaded', 'topic.title'),

  _composeChanged: function() {
    var composerController = Discourse.get('router.composerController');
    composerController.clearState();
    composerController.set('topic', this.get('topic'));
  }.observes('composer'),

  _enteredTopic: function() {
    this._topicProgress = undefined;

    // Ember is supposed to only call observers when values change but something
    // in our view set up is firing this observer with the same value. This check
    // prevents scrolled from being called twice.
    var enteredAt = this.get('controller.enteredAt');
    if (enteredAt && (this.get('lastEnteredAt') !== enteredAt)) {
      this.scrolled();
      this.set('lastEnteredAt', enteredAt);
    }
  }.observes('controller.enteredAt'),

  _inserted: function() {
    this.bindScrolling({name: 'topic-view'});

    var self = this;
    $(window).resize('resize.discourse-on-scroll', function() {
      self.scrolled();
    });

    // This get seems counter intuitive, but it's to trigger the observer on
    // the streamPercentage for this view. Otherwise the process bar does not
    // update.
    this.get('controller.streamPercentage');

    this.$().on('mouseup.discourse-redirect', '.cooked a, a.track-link', function(e) {
      var $target = $(e.target);
      if ($target.hasClass('mention') || $target.parents('.expanded-embed').length) { return false; }
      return Discourse.ClickTrack.trackClick(e);
    });
  }.on('didInsertElement'),

  // This view is being removed. Shut down operations
  _destroyed: function() {
    this.unbindScrolling('topic-view');
    $(window).unbind('resize.discourse-on-scroll');

    // Unbind link tracking
    this.$().off('mouseup.discourse-redirect', '.cooked a, a.track-link');

    this.resetExamineDockCache();

    // this happens after route exit, stuff could have trickled in
    this.set('controller.controllers.header.showExtraInfo', false);
  }.on('willDestroyElement'),

  debounceLoadSuggested: Discourse.debounce(function(){
    if (this.get('isDestroyed') || this.get('isDestroying')) { return; }

    var incoming = this.get('topicTrackingState.newIncoming'),
        suggested = this.get('topic.details.suggested_topics'),
        topicId = this.get('topic.id');

    if(suggested) {
      var existing = _.invoke(suggested, 'get', 'id'),
          lookup = _.chain(incoming)
                    .last(Discourse.SiteSettings.suggested_topics)
                    .reverse()
                    .union(existing)
                    .uniq()
                    .without(topicId)
                    .first(Discourse.SiteSettings.suggested_topics)
                    .value();

      Discourse.TopicList.loadTopics(lookup, "").then(function(topics){
        suggested.clear();
        suggested.pushObjects(topics);
      });
    }
  }, 1000),

  hasNewSuggested: function(){
    this.debounceLoadSuggested();
  }.observes('topicTrackingState.incomingCount'),

  gotFocus: function(){
    if (Discourse.get('hasFocus')){
      this.scrolled();
    }
  }.observes("Discourse.hasFocus"),

  resetExamineDockCache: function() {
    this.set('docAt', false);
  },

  /**
    The user has scrolled the window, or it is finished rendering and ready for processing.

    @method scrolled
  **/
  scrolled: function(){

    var offset = window.pageYOffset || $('html').scrollTop();
    if (!this.get('docAt')) {
      var title = $('#topic-title');
      if (title && title.length === 1) {
        this.set('docAt', title.offset().top);
      }
    }

    var headerController = this.get('controller.controllers.header'),
        topic = this.get('controller.model');
    if (this.get('docAt')) {
      headerController.set('showExtraInfo', offset >= this.get('docAt') || topic.get('postStream.firstPostNotLoaded'));
    } else {
      headerController.set('showExtraInfo', topic.get('postStream.firstPostNotLoaded'));
    }

    // Dock the counter if necessary
    var $lastPost = $('article[data-post-id=' + topic.get('postStream.lastPostId') + "]");
    var lastPostOffset = $lastPost.offset();
    if (!lastPostOffset) {
      this.set('controller.dockedCounter', false);
      return;
    }
    this.set('controller.dockedCounter', (offset >= (lastPostOffset.top + $lastPost.height()) - $(window).height()));
  },

  topicTrackingState: function() {
    return Discourse.TopicTrackingState.current();
  }.property(),

  browseMoreMessage: function() {
    var opts = { latestLink: "<a href=\"" + Discourse.getURL("/latest") + "\">" + I18n.t("topic.view_latest_topics") + "</a>" },
        category = this.get('controller.content.category');

    if(Em.get(category, 'id') === Discourse.Site.currentProp("uncategorized_category_id")) {
      category = null;
    }

    if (category) {
      opts.catLink = Discourse.HTML.categoryBadge(category, {showParent: true});
    } else {
      opts.catLink = "<a href=\"" + Discourse.getURL("/categories") + "\">" + I18n.t("topic.browse_all_categories") + "</a>";
    }

    var tracking = this.get('topicTrackingState'),
        unreadTopics = tracking.countUnread(),
        newTopics = tracking.countNew();

    if (newTopics + unreadTopics > 0) {
      var hasBoth = unreadTopics > 0 && newTopics > 0;

      return I18n.messageFormat("topic.read_more_MF", {
        "BOTH": hasBoth,
        "UNREAD": unreadTopics,
        "NEW": newTopics,
        "CATEGORY": category ? true : false,
        latestLink: opts.latestLink,
        catLink: opts.catLink
      });
    }
    else if (category) {
      return I18n.t("topic.read_more_in_category", opts);
    } else {
      return I18n.t("topic.read_more", opts);
    }
  }.property('topicTrackingState.messageCount')

});

Discourse.TopicView.reopenClass({

  jumpToPost: function(postNumber) {
    var holderId = '#post-cloak-' + postNumber;

    Em.run.schedule('afterRender', function() {
      if (postNumber === 1) {
        $(window).scrollTop(0);
        return;
      }

      new LockOn(holderId, {offsetCalculator: function() {
        var $header = $('header'),
            $title = $('#topic-title'),
            windowHeight = $(window).height() - $title.height(),
            expectedOffset = $title.height() - $header.find('.contents').height() + (windowHeight / 5);

        return $header.outerHeight(true) + ((expectedOffset < 0) ? 0 : expectedOffset);
      }}).lock();
    });
  }

});
