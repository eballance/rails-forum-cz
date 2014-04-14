load 'deploy'
load 'deploy/assets'
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'config/deploy' # remove this line to skip loading any of the default tasks
load 'config/deploy/settings'
# Dir['config/deploy/recipes/*.rb'].each { |f| load(f) }
load 'config/deploy/recipes/passenger'
load 'config/deploy/recipes/symlinks'
load 'config/deploy/recipes/vhost'
# load 'config/deploy/recipes/clockworks'
load 'config/deploy/recipes/logrotate'
