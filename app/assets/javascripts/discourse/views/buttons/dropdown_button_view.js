/**
  This view handles rendering of a button with an associated drop down

  @class DropdownButtonView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.DropdownButtonView = Discourse.View.extend({
  classNameBindings: [':btn-group', 'hidden'],
  shouldRerender: Discourse.View.renderIfChanged('text', 'longDescription'),

  didInsertElement: function() {
    var self = this;
    // If there's a click handler, call it
    if (self.clicked) {
      self.$('ul li').on('click.dropdown-button', function(e) {
        e.preventDefault();
        if ($(e.currentTarget).data('id') !== self.get('activeItem'))
          self.clicked($(e.currentTarget).data('id'));
        return false;
      });
    }
  },

  willDestroyElement: function() {
    this.$('ul li').off('click.dropdown-button');
  },

  render: function(buffer) {
    var self = this;
    var descriptionKey = self.get('descriptionKey') || 'description';

    buffer.push("<h4 class='title'>" + self.get('title') + "</h4>");
    buffer.push("<button class='btn standard dropdown-toggle' data-toggle='dropdown'>");
    buffer.push(self.get('text'));
    buffer.push("</button>");
    buffer.push("<ul class='dropdown-menu'>");

    _.each(self.get('dropDownContent'), function(row) {
      var id = row[0],
          textKey = row[1],
          iconClass = row[2],
          title = I18n.t(textKey + ".title"),
          description = I18n.t(textKey + "." + descriptionKey),
          className = (self.get('activeItem') === id? 'disabled': '');

      buffer.push("<li data-id=\"" + id + "\" class=\"" + className + "\"><a href='#'>");
      buffer.push("<span class='icon " + iconClass + "'></span>");
      buffer.push("<div><span class='title'>" + title + "</span>");
      buffer.push("<span>" + description + "</span></div>");
      buffer.push("</a></li>");
    });

    buffer.push("</ul>");

    var desc = self.get('longDescription');
    if (desc) {
      buffer.push("<p>");
      buffer.push(desc);
      buffer.push("</p>");
    }
  }
});
