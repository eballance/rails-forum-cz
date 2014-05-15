/**
  This controller supports actions when listing categories

  @class DiscoveryCategoriesController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
export default Discourse.DiscoveryController.extend({
  needs: ['modal', 'discovery'],

  actions: {
    toggleOrdering: function(){
      this.set("ordering",!this.get("ordering"));
    },

    refresh: function() {
      var self = this;

      // Don't refresh if we're still loading
      if (this.get('controllers.discovery.loading')) { return; }

      this.send('loading');
      Discourse.CategoryList.list('categories').then(function(list) {
        self.set('model', list);
        self.send('loadingComplete');
      });
    }
  },

  canEdit: function() {
    return Discourse.User.currentProp('staff');
  }.property(),

  moveCategory: function(categoryId, position){
    this.get('model.categories').moveCategory(categoryId, position);
  },

  latestTopicOnly: function() {
    return this.get('categories').find(function(c) { return c.get('featuredTopics.length') > 1; }) === undefined;
  }.property('categories.@each.featuredTopics.length')

});
