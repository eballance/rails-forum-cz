/**
  Initialize the message bus to receive messages.
**/
Discourse.addInitializer(function() {

  // We don't use the message bus in testing
  if (Discourse.testing) { return; }

  Discourse.MessageBus.alwaysLongPoll = Discourse.Environment === "development";
  Discourse.MessageBus.start();

  Discourse.MessageBus.subscribe("/global/asset-version", function(version){
    Discourse.set("assetVersion", version);

    if(Discourse.get("requiresRefresh")) {
      // since we can do this transparently for people browsing the forum
      //  hold back the message a couple of hours
      setTimeout(function() {
        bootbox.confirm(I18n.lookup("assets_changed_confirm"), function(result){
          if (result) {
            document.location.reload();
          }
        });
      }, 1000 * 60 * 120);
    }

  });

  // initialize read-only mode and subscribe to updates via the message bus
  Discourse.set("isReadOnly", Discourse.Site.currentProp("is_readonly"));
  Discourse.MessageBus.subscribe("/site/read-only", function (enabled) {
    Discourse.set("isReadOnly", enabled);
  });

  Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus);
}, true);
