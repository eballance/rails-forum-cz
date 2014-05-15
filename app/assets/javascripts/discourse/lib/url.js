/**
  URL related functions.

  @class URL
  @namespace Discourse
  @module Discourse
**/
Discourse.URL = Em.Object.createWithMixins({

  // Used for matching a topic
  TOPIC_REGEXP: /\/t\/([^\/]+)\/(\d+)\/?(\d+)?/,

  /**
    Browser aware replaceState. Will only be invoked if the browser supports it.

    @method replaceState
    @param {String} path The path we are replacing our history state with.
  **/
  replaceState: function(path) {
    if (window.history &&
        window.history.pushState &&
        window.history.replaceState &&
        !navigator.userAgent.match(/((iPod|iPhone|iPad).+\bOS\s+[1-4]|WebApps\/.+CFNetwork)/) &&
        (window.location.pathname !== path)) {

        // Always use replaceState in the next runloop to prevent weird routes changing
        // while URLs are loading. For example, while a topic loads it sets `currentPost`
        // which triggers a replaceState even though the topic hasn't fully loaded yet!
        Em.run.next(function() {
          var location = Discourse.URL.get('router.location');
          if (location && location.replaceURL) {

            if (Ember.FEATURES.isEnabled("query-params-new")) {
              var search = Discourse.__container__.lookup('router:main').get('location.location.search') || '';
              path += search;
            }
            location.replaceURL(path);
          }
        });
    }
  },

  /**
    Our custom routeTo method is used to intelligently overwrite default routing
    behavior.

    It contains the logic necessary to route within a topic using replaceState to
    keep the history intact.

    @method routeTo
    @param {String} path The path we are routing to.
  **/
  routeTo: function(path) {

    if (Em.isEmpty(path)) { return; }

    if(Discourse.get("requiresRefresh")){
      document.location.href = path;
      return;
    }

    // Protocol relative URLs
    if (path.indexOf('//') === 0) {
      document.location = path;
      return;
    }

    // Scroll to the same page, differnt anchor
    if (path.indexOf('#') === 0) {
      var $elem = $(path);
      if ($elem.length > 0) {
        Em.run.schedule('afterRender', function() {
          $('html,body').scrollTop($elem.offset().top - $('header').height() - 15);
        });
      }
      return;
    }

    var oldPath = window.location.pathname;
    path = path.replace(/(https?\:)?\/\/[^\/]+/, '');

    // handle prefixes
    if (path.match(/^\//)) {
      var rootURL = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);
      rootURL = rootURL.replace(/\/$/, '');
      path = path.replace(rootURL, '');
    }

    // Schedule a DOM cleanup event
    Em.run.scheduleOnce('afterRender', Discourse.Route, 'cleanDOM');

    // Rewrite /my/* urls
    if (path.indexOf('/my/') === 0) {
      var currentUser = Discourse.User.current();
      if (currentUser) {
        path = path.replace('/my/', '/users/' + currentUser.get('username_lower') + "/");
      } else {
        document.location.href = "/404";
        return;
      }
    }

    // TODO: Extract into rules we can inject into the URL handler
    if (this.navigatedToHome(oldPath, path)) { return; }
    if (this.navigatedToPost(oldPath, path)) { return; }

    if (path.match(/^\/?users\/[^\/]+$/)) {
      path += "/activity";
    }

    return this.handleURL(path);
  },

  /**
    Redirect to a URL.
    This has been extracted so it can be tested.

    @method redirectTo
  **/
  redirectTo: function(url) {
    window.location = Discourse.getURL(url);
  },

  /**
   * Determines whether a URL is internal or not
   *
   * @method isInternal
   * @param {String} url
  **/
  isInternal: function(url) {
    if (url && url.length) {
      if (url.indexOf('/') === 0) { return true; }
      if (url.indexOf(this.origin()) === 0) { return true; }
      if (url.replace(/^http/, 'https').indexOf(this.origin()) === 0) { return true; }
      if (url.replace(/^https/, 'http').indexOf(this.origin()) === 0) { return true; }
    }
    return false;
  },

  /**
    @private

    If the URL is in the topic form, /t/something/:topic_id/:post_number
    then we want to apply some special logic. If the post_number changes within the
    same topic, use replaceState and instruct our controller to load more posts.

    @method navigatedToPost
    @param {String} oldPath the previous path we were on
    @param {String} path the path we're navigating to
  **/
  navigatedToPost: function(oldPath, path) {
    var newMatches = this.TOPIC_REGEXP.exec(path),
        newTopicId = newMatches ? newMatches[2] : null;

    if (newTopicId) {
      var oldMatches = this.TOPIC_REGEXP.exec(oldPath),
          oldTopicId = oldMatches ? oldMatches[2] : null;

      // If the topic_id is the same
      if (oldTopicId === newTopicId) {
        Discourse.URL.replaceState(path);

        var topicController = Discourse.__container__.lookup('controller:topic'),
            opts = {},
            postStream = topicController.get('postStream');

        if (newMatches[3]) opts.nearPost = newMatches[3];
        if (path.match(/last$/)) { opts.nearPost = topicController.get('highest_post_number'); }
        var closest = opts.nearPost || 1;

        postStream.refresh(opts).then(function() {
          topicController.setProperties({
            currentPost: closest,
            progressPosition: closest,
            highlightOnInsert: closest,
            enteredAt: new Date().getTime().toString()
          });
        }).then(function() {
          Discourse.TopicView.jumpToPost(closest);
        });

        // Abort routing, we have replaced our state.
        return true;
      }
    }

    return false;
  },

  /**
    @private

    Handle the custom case of routing to the root path from itself.

    @param {String} oldPath the previous path we were on
    @param {String} path the path we're navigating to
  **/
  navigatedToHome: function(oldPath, path) {
    var homepage = Discourse.Utilities.defaultHomepage();

    if (path === "/" && (oldPath === "/" || oldPath === "/" + homepage)) {
      // refresh the list
      switch (homepage) {
        case "top" :       { this.controllerFor('discovery/top').send('refresh'); break; }
        case "categories": { this.controllerFor('discovery/categories').send('refresh'); break; }
        default:           { this.controllerFor('discovery/topics').send('refresh'); break; }
      }
      return true;
    }

    return false;
  },

  /**
    @private

    Get the origin of the current location.
    This has been extracted so it can be tested.

    @method origin
  **/
  origin: function() {
    return window.location.origin;
  },

  /**
    @private

    Get a handle on the application's router. Note that currently it uses `__container__` which is not
    advised but there is no other way to access the router.

    @property router
  **/
  router: function() {
    return Discourse.__container__.lookup('router:main');
  }.property(),

  /**
    @private

    Get a controller. Note that currently it uses `__container__` which is not
    advised but there is no other way to access the router.

    @method controllerFor
    @param {String} name the name of the controller
  **/
  controllerFor: function(name) {
    return Discourse.__container__.lookup('controller:' + name);
  },

  /**
    @private

    Be wary of looking up the router. In this case, we have links in our
    HTML, say form compiled markdown posts, that need to be routed.

    @method handleURL
    @param {String} path the url to handle
  **/
  handleURL: function(path) {
    var router = this.get('router');
    router.router.updateURL(path);

    var split = path.split('#'),
        elementId;

    if (split.length === 2) {
      path = split[0];
      elementId = split[1];
    }

    var transition = router.handleURL(path);
    transition.promise.then(function() {
      if (elementId) {
        Em.run.next('afterRender', function() {
          var offset = $('#' + elementId).offset();
          if (offset && offset.top) {
            $('html, body').scrollTop(offset.top - $('header').height() - 10);
          }
        });
      }
    });
  }

});
