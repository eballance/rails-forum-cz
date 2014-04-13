/**
  Keyboard Shortcut related functions.

  @class KeyboardShortcuts
  @namespace Discourse
  @module Discourse
**/
Discourse.KeyboardShortcuts = Ember.Object.createWithMixins({
  PATH_BINDINGS: {
    'g h': '/',
    'g l': '/latest',
    'g n': '/new',
    'g u': '/unread',
    'g f': '/starred',
    'g c': '/categories',
    'g t': '/top'
  },

  CLICK_BINDINGS: {
    'b': 'article.selected button.bookmark',                      // bookmark current post
    'c': '#create-topic',                                         // create new topic
    'd': 'article.selected button.delete',                        // delete selected post
    'e': 'article.selected button.edit',                          // edit selected post

    // star topic
    'f': '#topic-footer-buttons button.star, #topic-list tr.topic-list-item.selected a.star',

    'l': 'article.selected button.like',                          // like selected post
    'm m': 'div.notification-options li[data-id="0"] a',          // mark topic as muted
    'm r': 'div.notification-options li[data-id="1"] a',          // mark topic as regular
    'm t': 'div.notification-options li[data-id="2"] a',          // mark topic as tracking
    'm w': 'div.notification-options li[data-id="3"] a',          // mark topic as watching
    'n': '#user-notifications',                                   // open notifictions menu
    'o,enter': '#topic-list tr.topic-list-item.selected a.title', // open selected topic
    'r': '#topic-footer-buttons button.create',                   // reply to topic
    'R': 'article.selected button.create',                        // reply to selected post
    's': '#topic-footer-buttons button.share',                    // share topic
    'S': 'article.selected button.share',                         // share selected post
    '!': 'article.selected button.flag'                           // flag selected post
  },

  FUNCTION_BINDINGS: {
    'home': 'goToFirstPost',
    'end': 'goToLastPost',
    'j': 'selectDown',
    'k': 'selectUp',
    'u': 'goBack',
    '`': 'nextSection',
    '~': 'prevSection',
    '/': 'showSearch',
    '?': 'showHelpModal'                                          // open keyboard shortcut help
  },

  bindEvents: function(keyTrapper) {
    this.keyTrapper = keyTrapper;
    _.each(this.PATH_BINDINGS, this._bindToPath, this);
    _.each(this.CLICK_BINDINGS, this._bindToClick, this);
    _.each(this.FUNCTION_BINDINGS, this._bindToFunction, this);
  },

  goToFirstPost: function() {
    this._jumpTo('jumpTop');
  },

  goToLastPost: function() {
    this._jumpTo('jumpBottom');
  },

  _jumpTo: function(direction) {
    if ($('#topic-title').length) {
      Discourse.__container__.lookup('controller:topic').send(direction);
    }
  },

  selectDown: function() {
    this._moveSelection(1);
  },

  selectUp: function() {
    this._moveSelection(-1);
  },

  goBack: function() {
    history.back();
  },

  nextSection: function() {
    this._changeSection(1);
  },

  prevSection: function() {
    this._changeSection(-1);
  },

  showSearch: function() {
    $('#search-button').click();
    return false;
  },

  showHelpModal: function() {
    Discourse.__container__.lookup('controller:application').send('showKeyboardShortcutsHelp');
  },

  _bindToPath: function(path, binding) {
    this.keyTrapper.bind(binding, function() {
      Discourse.URL.routeTo(path);
    });
  },

  _bindToClick: function(selector, binding) {
    binding = binding.split(',');
    this.keyTrapper.bind(binding, function() {
      $(selector).click();
    });
  },

  _bindToFunction: function(func, binding) {
    if (typeof this[func] === 'function') {
      this.keyTrapper.bind(binding, _.bind(this[func], this));
    }
  },

  _moveSelection: function(direction) {
    var $articles = this._findArticles();

    if (typeof $articles === 'undefined') {
      return;
    }

    var $selected = $articles.filter('.selected'),
        index = $articles.index($selected);

    // loop is not allowed
    if (direction === -1 && index === 0) { return; }

    var $article = $articles.eq(index + direction);

    if ($article.size() > 0) {
      $articles.removeClass('selected');
      $article.addClass('selected');

      var rgx = new RegExp("post-cloak-(\\d+)").exec($article.parent()[0].id);
      if (rgx === null || typeof rgx[1] === 'undefined') {
          this._scrollList($article);
      } else {
          Discourse.TopicView.jumpToPost(rgx[1]);
      }
    }
  },

  _scrollList: function($article) {
    var $body = $('body'),
        distToElement = $article.position().top + $article.height() - $(window).height() - $body.scrollTop();

    $('html, body').scrollTop($body.scrollTop() + distToElement);
  },

  _findArticles: function() {
    var $topicList = $('#topic-list'),
        $topicArea = $('.posts-wrapper');

    if ($topicArea.size() > 0) {
      return $topicArea.find('.topic-post');
    }
    else if ($topicList.size() > 0) {
      return $topicList.find('.topic-list-item');
    }
  },

  _changeSection: function(direction) {
    var $sections = $('#navigation-bar').find('li'),
        index = $sections.index('.active');

    $sections.eq(index + direction).find('a').click();
  }
});
