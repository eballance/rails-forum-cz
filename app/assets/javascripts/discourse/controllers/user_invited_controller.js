/**
  This controller handles actions related to a user's invitations

  @class UserInvitedController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserInvitedController = Ember.ObjectController.extend({
  user: null,

  init: function() {
    this._super();
    this.set('searchTerm', '');
  },

  /**
    Observe the search term box with a debouncer and change the results.

    @observes searchTerm
  **/
  _searchTermChanged: Discourse.debounce(function() {
    var self = this;
    Discourse.Invite.findInvitedBy(self.get('user'), this.get('searchTerm')).then(function (invites) {
      self.set('model', invites);
    });
  }, 250).observes('searchTerm'),

  /**
    The maximum amount of invites that will be displayed in the view

    @property maxInvites
  **/
  maxInvites: function() {
    return Discourse.SiteSettings.invites_shown;
  }.property(),

  /**
    Can the currently logged in user invite users to the site

    @property canInviteToForum
  **/
  canInviteToForum: function() {
    return Discourse.User.currentProp('can_invite_to_forum');
  }.property(),

  /**
    Should the search filter input box be displayed?

    @property showSearch
  **/
  showSearch: function() {
    return !(Em.isNone(this.get('searchTerm')) && this.get('invites.length') === 0);
  }.property('searchTerm', 'invites.length'),

  /**
    Were the results limited by our `maxInvites`

    @property truncated
  **/
  truncated: function() {
    return this.get('invites.length') === Discourse.SiteSettings.invites_shown;
  }.property('invites.length'),

  actions: {

    /**
      Rescind a given invite

      @method rescive
      @param {Discourse.Invite} invite the invite to rescind.
    **/
    rescind: function(invite) {
      invite.rescind();
      return false;
    }
  }

});


