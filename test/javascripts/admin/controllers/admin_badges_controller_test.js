module("Discourse.AdminBadgesController");

test("showDisplayName", function() {
  var badge, controller;

  badge = Discourse.Badge.create({name: "Test Badge"});
  controller = testController(Discourse.AdminBadgesController, [badge]);
  controller.send('selectBadge', badge);
  ok(!controller.get('showDisplayName'), "does not show displayName when it is the same as the name");

  this.stub(I18n, "t").returns("translated string");
  badge = Discourse.Badge.create({name: "Test Badge"});
  controller = testController(Discourse.AdminBadgesController, [badge]);
  controller.send('selectBadge', badge);
  ok(controller.get('showDisplayName'), "shows the displayName when it is different from the name");
});

test("canEditDescription", function() {
  var badge, controller;

  badge = Discourse.Badge.create({name: "Test Badge"});
  controller = testController(Discourse.AdminBadgesController, [badge]);
  controller.send('selectBadge', badge);
  ok(controller.get('canEditDescription'), "allows editing description when a translation exists for the badge name");

  this.stub(I18n, "t").returns("translated string");
  badge = Discourse.Badge.create({name: "Test Badge"});
  controller = testController(Discourse.AdminBadgesController, [badge]);
  controller.send('selectBadge', badge);
  ok(!controller.get('canEditDescription'), "shows the displayName when it is different from the name");
});

test("newBadge", function() {
  var controller = testController(Discourse.AdminBadgesController, []);
  controller.send('newBadge');
  equal(controller.get('model.length'), 1, "adds a new badge to the list of badges");
  equal(controller.get('model')[0], controller.get('selectedItem'), "the new badge is selected");
});

test("selectBadge", function() {
  var badge = Discourse.Badge.create({name: "Test Badge"}),
      controller = testController(Discourse.AdminBadgesController, [badge]);

  controller.send('selectBadge', badge);
  equal(controller.get('selectedItem'), badge, "the badge is selected");
});

test("save", function() {
  var badge = Discourse.Badge.create({name: "Test Badge"}),
      otherBadge = Discourse.Badge.create({name: "Other Badge"}),
      controller = testController(Discourse.AdminBadgesController, [badge, otherBadge]);

  controller.send('selectBadge', badge);
  this.stub(badge, "save").returns(Ember.RSVP.resolve({}));
  controller.send("save");
  ok(badge.save.calledOnce, "called save on the badge");
});

test("destroy", function() {
  var badge = Discourse.Badge.create({name: "Test Badge"}),
      otherBadge = Discourse.Badge.create({name: "Other Badge"}),
      controller = testController(Discourse.AdminBadgesController, [badge, otherBadge]);

  this.stub(badge, 'destroy').returns(Ember.RSVP.resolve({}));

  bootbox.confirm = function(text, yes, no, func) {
    func(false);
  };

  controller.send('selectBadge', badge);
  controller.send('destroy');
  ok(!badge.destroy.calledOnce, "badge is not destroyed if they user clicks no");

  bootbox.confirm = function(text, yes, no, func) {
    func(true);
  };

  controller.send('selectBadge', badge);
  controller.send('destroy');
  ok(badge.destroy.calledOnce, "badge is destroyed if they user clicks yes");
});
