/**
  Breaks up a long string

  @method breakUp
  @for Handlebars
**/
Handlebars.registerHelper('breakUp', function(property, hint, options) {
  var prop = Ember.Handlebars.get(this, property, options);
  if (!prop) return "";
  if (typeof(hint) === 'string') {
    hint = Ember.Handlebars.get(this, hint, options);
  } else {
    hint = undefined;
  }

  return new Handlebars.SafeString(Discourse.Formatter.breakUp(prop, hint));
});

// helper function for dates
function daysSinceEpoch(dt) {
  // 1000 * 60 * 60 * 24 = days since epoch
  return dt.getTime() / 86400000;
}

/**
  Converts a date to a coldmap class

  @method coldDate
**/
Handlebars.registerHelper('coldAgeClass', function(property, options) {
  var dt = Em.Handlebars.get(this, property, options);

  if (!dt) { return 'age'; }

  // Show heat on age
  var nowDays = daysSinceEpoch(new Date()),
      epochDays = daysSinceEpoch(new Date(dt));
  if (nowDays - epochDays > 60) return 'age coldmap-high';
  if (nowDays - epochDays > 30) return 'age coldmap-med';
  if (nowDays - epochDays > 14) return 'age coldmap-low';

  return 'age';
});


/**
  Truncates long strings

  @method shorten
  @for Handlebars
**/
Handlebars.registerHelper('shorten', function(property, options) {
  return Ember.Handlebars.get(this, property, options).substring(0,35);
});

/**
  Produces a link to a topic

  @method topicLink
  @for Handlebars
**/
Handlebars.registerHelper('topicLink', function(property, options) {
  var topic = Ember.Handlebars.get(this, property, options),
      title = topic.get('fancy_title');
  return "<a href='" + topic.get('lastUnreadUrl') + "' class='title'>" + title + "</a>";
});


/**
  Produces a link to a category given a category object and helper options

  @method categoryLinkHTML
  @param {Discourse.Category} category to link to
  @param {Object} options standard from handlebars
**/
function categoryLinkHTML(category, options) {
  var categoryOptions = {};
  if (options.hash) {
    if (options.hash.allowUncategorized) { categoryOptions.allowUncategorized = true; }
    if (options.hash.showParent) { categoryOptions.showParent = true; }
    if (options.hash.link !== undefined) { categoryOptions.link = options.hash.link; }
    if (options.hash.extraClasses) { categoryOptions.extraClasses = options.hash.extraClasses; }
    if (options.hash.categories) {
      categoryOptions.categories = Em.Handlebars.get(this, options.hash.categories, options);
    }
  }
  return new Handlebars.SafeString(Discourse.HTML.categoryBadge(category, categoryOptions));
}

/**
  Produces a link to a category

  @method categoryLink
  @for Handlebars
**/
Handlebars.registerHelper('categoryLink', function(property, options) {
  return categoryLinkHTML(Ember.Handlebars.get(this, property, options), options);
});

Handlebars.registerHelper('categoryLinkRaw', function(property, options) {
  return categoryLinkHTML(property, options);
});

Handlebars.registerHelper('categoryBadge', function(property, options) {
  options.hash.link = false;
  return categoryLinkHTML(Ember.Handlebars.get(this, property, options), options);
});


/**
  Produces a bound link to a category

  @method boundCategoryLink
  @for Handlebars
**/
Ember.Handlebars.registerBoundHelper('boundCategoryLink', categoryLinkHTML);

/**
  Produces a link to a route with support for i18n on the title

  @method titledLinkTo
  @for Handlebars
**/
Handlebars.registerHelper('titledLinkTo', function(name, object) {
  var options = [].slice.call(arguments, -1)[0];
  if (options.hash.titleKey) {
    options.hash.title = I18n.t(options.hash.titleKey);
  }
  if (arguments.length === 3) {
    return Ember.Handlebars.helpers['link-to'].call(this, name, object, options);
  } else {
    return Ember.Handlebars.helpers['link-to'].call(this, name, options);
  }
});

/**
  Shorten a URL for display by removing common components

  @method shortenUrl
  @for Handlebars
**/
Handlebars.registerHelper('shortenUrl', function(property, options) {
  var url, matches;
  url = Ember.Handlebars.get(this, property, options);
  // Remove trailing slash if it's a top level URL
  matches = url.match(/\//g);
  if (matches && matches.length === 3) {
    url = url.replace(/\/$/, '');
  }
  url = url.replace(/^https?:\/\//, '');
  url = url.replace(/^www\./, '');
  return url.substring(0,80);
});

/**
  Display a property in lower case

  @method lower
  @for Handlebars
**/
Handlebars.registerHelper('lower', function(property, options) {
  var o;
  o = Ember.Handlebars.get(this, property, options);
  if (o && typeof o === 'string') {
    return o.toLowerCase();
  } else {
    return "";
  }
});

/**
  Show an avatar for a user, intelligently making use of available properties

  @method avatar
  @for Handlebars
**/
Handlebars.registerHelper('avatar', function(user, options) {
  if (typeof user === 'string') {
    user = Ember.Handlebars.get(this, user, options);
  }

  if (user) {
    var username = Em.get(user, 'username');
    if (!username) username = Em.get(user, options.hash.usernamePath);

    var avatarTemplate;
    var template = options.hash.template;
    if (template && template !== 'avatar_template') {
      avatarTemplate = Em.get(user, template);
      if (!avatarTemplate) avatarTemplate = Em.get(user, 'user.' + template);
    }

    if (!avatarTemplate) avatarTemplate = Em.get(user, 'avatar_template');
    if (!avatarTemplate) avatarTemplate = Em.get(user, 'user.avatar_template');

    var title;
    if (!options.hash.ignoreTitle) {
      // first try to get a title
      title = Em.get(user, 'title');
      // if there was no title provided
      if (!title) {
        // try to retrieve a description
        var description = Em.get(user, 'description');
        // if a description has been provided
        if (description && description.length > 0) {
          // preprend the username before the description
          title = username + " - " + description;
        }
      }
    }

    return new Handlebars.SafeString(Discourse.Utilities.avatarImg({
      size: options.hash.imageSize,
      extraClasses: Em.get(user, 'extras') || options.hash.extraClasses,
      title: title || username,
      avatarTemplate: avatarTemplate
    }));
  } else {
    return '';
  }
});

/**
  Bound avatar helper.
  Will rerender whenever the "avatar_template" changes.

  @method boundAvatar
  @for Handlebars
**/
Ember.Handlebars.registerBoundHelper('boundAvatar', function(user, options) {
  return new Handlebars.SafeString(Discourse.Utilities.avatarImg({
    size: options.hash.imageSize,
    avatarTemplate: Em.get(user, options.hash.template || 'avatar_template')
  }));
}, 'avatar_template', 'uploaded_avatar_template', 'gravatar_template');

/**
  Nicely format a date without binding or returning HTML

  @method rawDate
  @for Handlebars
**/
Handlebars.registerHelper('rawDate', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return Discourse.Formatter.longDate(dt);
});

/**
  Live refreshing age helper

  @method unboundAge
  @for Handlebars
**/
Handlebars.registerHelper('unboundAge', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(dt));
});

/**
  Live refreshing age helper, with a tooltip showing the date and time

  @method unboundAgeWithTooltip
  @for Handlebars
**/
Handlebars.registerHelper('unboundAgeWithTooltip', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(dt, {title: true}));
});

/**
  Display a date related to an edit of a post

  @method editDate
  @for Handlebars
**/
Handlebars.registerHelper('editDate', function(property, options) {
  // autoupdating this is going to be painful
  var date = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(date, {format: 'medium', title: true, leaveAgo: true, wrapInSpan: false}));
});

/**
  Displays a percentile based on a `percent_rank` field

  @method percentile
  @for Ember.Handlebars
**/
Ember.Handlebars.registerHelper('percentile', function(property, options) {
  var percentile = Ember.Handlebars.get(this, property, options);
  return Math.round((1.0 - percentile) * 100);
});

/**
  Displays a float nicely

  @method float
  @for Ember.Handlebars
**/
Ember.Handlebars.registerHelper('float', function(property, options) {
  var x = Ember.Handlebars.get(this, property, options);
  if (!x) return "0";
  if (Math.round(x) === x) return x;
  return x.toFixed(3);
});

/**
  Display logic for numbers.

  @method number
  @for Handlebars
**/
Handlebars.registerHelper('number', function(property, options) {

  var orig = parseInt(Ember.Handlebars.get(this, property, options), 10);
  if (isNaN(orig)) { orig = 0; }

  var title = orig;
  if (options.hash.numberKey) {
    title = I18n.t(options.hash.numberKey, { number: orig });
  }

  var classNames = 'number';
  if (options.hash['class']) {
    classNames += ' ' + Ember.Handlebars.get(this, options.hash['class'], options);
  }
  var result = "<span class='" + classNames + "'";

  // Round off the thousands to one decimal place
  var n = Discourse.Formatter.number(orig);
  if (n !== title) {
    result += " title='" + Handlebars.Utils.escapeExpression(title) + "'";
  }
  result += ">" + n + "</span>";

  return new Handlebars.SafeString(result);
});

/**
  Display logic for dates. It is unbound in Ember but will use jQuery to
  update the dates on a regular interval.

  @method unboundDate
  @for Handlebars
**/
Handlebars.registerHelper('unboundDate', function(property, options) {
  var leaveAgo;
  if (property.hash) {
    if (property.hash.leaveAgo) {
      leaveAgo = property.hash.leaveAgo === "true";
    }
    if (property.hash.path) {
      property = property.hash.path;
    }
  }

  var val = Ember.Handlebars.get(this, property, options);
  if (val) {
    var date = new Date(val);
    return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(date, {format: 'medium', title: true, leaveAgo: leaveAgo}));
  }
});

Ember.Handlebars.registerBoundHelper('date', function(dt) {
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(new Date(dt), {format: 'medium', title: true }));
});

/**
  Look for custom html content using `Discourse.HTML`. If none exists, look for a template
  to render with that name.

  @method customHTML
  @for Handlebars
**/
Handlebars.registerHelper('customHTML', function(name, contextString, options) {
  var html = Discourse.HTML.getCustomHTML(name);
  if (html) { return html; }

  var container = (options || contextString).data.keywords.controller.container;

  if (container.lookup('template:' + name)) {
    return Ember.Handlebars.helpers.partial.apply(this, arguments);
  }
});

Ember.Handlebars.registerBoundHelper('humanSize', function(size) {
  return new Handlebars.SafeString(I18n.toHumanSize(size));
});

/**
  Renders the domain for a link if it's not internal and has a title.

  @method link-domain
  @for Handlebars
**/
Handlebars.registerHelper('link-domain', function(property, options) {
  var link = Em.get(this, property, options);
  if (link) {
    var internal = Em.get(link, 'internal'),
        hasTitle = (!Em.isEmpty(Em.get(link, 'title')));
    if (hasTitle && !internal) {
      var domain = Em.get(link, 'domain');
      if (!Em.isEmpty(domain)) {
        var s = domain.split('.');
        domain = s[s.length-2] + "." + s[s.length-1];
        return new Handlebars.SafeString("<span class='domain'>" + domain + "</span>");
      }
    }
  }
});

/**
  Renders a font-awesome icon with an optional i18n string as hidden text for
  screen readers.

  @method icon
  @for Handlebars
**/
Handlebars.registerHelper('icon', function(icon, options) {
  var labelKey, html;
  if (options.hash) { labelKey = options.hash.label; }
  html = "<i class='fa fa-" + icon + "'";
  if (labelKey) { html += " aria-hidden='true'"; }
  html += "></i>";
  if (labelKey) {
    html += "<span class='sr-only'>" + I18n.t(labelKey) + "</span>";
  }
  return new Handlebars.SafeString(html);
});
