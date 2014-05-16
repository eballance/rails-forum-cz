/*global Favcount:true*/

/**
  The main Discourse Application

  @class Discourse
  @extends Ember.Application
**/
window.Discourse = Ember.Application.createWithMixins(Discourse.Ajax, {
  rootElement: '#main',

  // Helps with integration tests
  URL_FIXTURES: {},

  getURL: function(url) {
    // If it's a non relative URL, return it.
    if (url.indexOf('http') === 0) return url;

    var u = (Discourse.BaseUri === undefined ? "/" : Discourse.BaseUri);
    if (u[u.length-1] === '/') {
      u = u.substring(0, u.length-1);
    }
    if (url.indexOf(u) !== -1) return url;
    return u + url;
  },

  Resolver: Discourse.Resolver,

  titleChanged: function() {
    var title = "";

    if (this.get('title')) {
      title += "" + (this.get('title')) + " - ";
    }
    title += Discourse.SiteSettings.title;
    $('title').text(title);

    var notifyCount = this.get('notifyCount');
    if (notifyCount > 0 && !Discourse.User.currentProp('dynamic_favicon')) {
      title = "(" + notifyCount + ") " + title;
    }

    if(title !== document.title) {
      // chrome bug workaround see: http://stackoverflow.com/questions/2952384/changing-the-window-title-when-focussing-the-window-doesnt-work-in-chrome
      window.setTimeout(function() {
        document.title = ".";
        document.title = title;
      }, 200);
    }
  }.observes('title', 'hasFocus', 'notifyCount'),

  faviconChanged: function() {
    if(Discourse.User.currentProp('dynamic_favicon')) {
      new Favcount(Discourse.SiteSettings.favicon_url).set(
        this.get('notifyCount')
      );
    }
  }.observes('notifyCount'),

  // The classes of buttons to show on a post
  postButtons: function() {
    return Discourse.SiteSettings.post_menu.split("|").map(function(i) {
      return (i.replace(/\+/, '').capitalize());
    });
  }.property(),

  notifyTitle: function(count) {
    this.set('notifyCount', count);
  },

  /**
    Log the current user out of Discourse

    @method logout
  **/
  logout: function() {
    Discourse.User.logout().then(function() {
      // Reloading will refresh unbound properties
      Discourse.KeyValueStore.abandonLocal();
      window.location.pathname = Discourse.getURL('/');
    });
  },

  authenticationComplete: function(options) {
    // TODO, how to dispatch this to the controller without the container?
    var loginController = Discourse.__container__.lookup('controller:login');
    return loginController.authenticationComplete(options);
  },

  loginRequired: function() {
    return Discourse.SiteSettings.login_required && !Discourse.User.current();
  }.property(),

  redirectIfLoginRequired: function(route) {
    if(this.get('loginRequired')) { route.transitionTo('login'); }
  },

  /**
    Add an initializer hook for after the Discourse Application starts up.

    @method addInitializer
    @param {Function} init the initializer to add.
    @param {Boolean} immediate whether to execute the function right away.
                      Default is false, for next run loop. If unsure, use false.
  **/
  addInitializer: function(init, immediate) {
    Discourse.initializers = Discourse.initializers || [];
    Discourse.initializers.push({fn: init, immediate: !!immediate});
  },

  /**
    Start up the Discourse application by running all the initializers we've defined.

    @method start
  **/
  start: function() {

    // Load any ES6 initializers
    Ember.keys(requirejs._eak_seen).filter(function(key) {
      return (/\/initializers\//).test(key);
    }).forEach(function(moduleName) {
      var module = require(moduleName, null, null, true);
      if (!module) { throw new Error(moduleName + ' must export an initializer.'); }
      Discourse.initializer(module.default);
    });

    var initializers = this.initializers;
    if (initializers) {
      var self = this;
      initializers.forEach(function (init) {
        if (init.immediate) {
          init.fn.call(self);
        } else {
          Em.run.next(function() {
            init.fn.call(self);
          });
        }
      });
    }

  },

  requiresRefresh: function(){
    var desired = Discourse.get("desiredAssetVersion");
    return desired && Discourse.get("currentAssetVersion") !== desired;
  }.property("currentAssetVersion", "desiredAssetVersion"),

  assetVersion: function(prop, val) {
    if(val) {
      if(this.get("currentAssetVersion")){
        this.set("desiredAssetVersion", val);
      } else {
        this.set("currentAssetVersion", val);
      }
    }
    return this.get("currentAssetVersion");
  }.property(),

  globalNotice: function(){
    var notices = [];

    if(this.get("isReadOnly")){
      notices.push(I18n.t("read_only_mode.enabled"));
    }

    if(!_.isEmpty(Discourse.SiteSettings.global_notice)){
      notices.push(Discourse.SiteSettings.global_notice);
    }

    if(notices.length > 0) {
      return new Handlebars.SafeString(_.map(notices, function(text) {
        return "<div class='row'><div class='alert alert-info'>" + text + "</div></div>";
      }).join(""));
    }
  }.property("isReadOnly")

});
