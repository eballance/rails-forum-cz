set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'
require "bundler/capistrano"
require 'sidekiq/capistrano'

set :application, "rails-forum"
set :domain, "rails-forum.cz"

# ssh_options[:forward_agent] = true
