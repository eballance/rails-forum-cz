# STAGING-specific deployment configuration
# please put general deployment config in config/deploy/settings.rb

set :user, "#{application}-stg"
set :domain, "#{application}.stg.eballance.cz"
set :is_root_domain, false
set :root_domain, ""
set :branch, "latest-release"

set :deploy_to, "/home/#{user}/web"
set :rails_env, "staging"

set :default_environment, {
  "PATH" => "/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH"
}
