# PRODUCTION-specific deployment configuration
# please put general deployment config in config/deploy/settings.rb

set :user, "#{application}"
set :is_root_domain, true
set :root_domain, "www.#{domain}"
set :branch, "master"

set :deploy_to, "/home/#{user}/web"
set :rails_env, "production"

set :default_environment, {
  "PATH" => "/usr/local/rbenv/shims:/usr/local/rbenv/bin:$PATH"
}
