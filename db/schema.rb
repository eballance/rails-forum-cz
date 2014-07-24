# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130807202516) do

  create_table "blocked_emails", :force => true do |t|
    t.string   "email",                        :null => false
    t.integer  "action_type",                  :null => false
    t.integer  "match_count",   :default => 0, :null => false
    t.datetime "last_match_at"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
  end

  add_index "blocked_emails", ["email"], :name => "index_blocked_emails_on_email", :unique => true
  add_index "blocked_emails", ["last_match_at"], :name => "index_blocked_emails_on_last_match_at"

  create_table "cas_user_infos", :force => true do |t|
    t.integer  "user_id",     :null => false
    t.string   "cas_user_id", :null => false
    t.string   "username",    :null => false
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.string   "gender"
    t.string   "name"
    t.string   "link"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "cas_user_infos", ["cas_user_id"], :name => "index_cas_user_infos_on_cas_user_id", :unique => true
  add_index "cas_user_infos", ["user_id"], :name => "index_cas_user_infos_on_user_id", :unique => true

  create_table "categories", :force => true do |t|
    t.string   "name",            :limit => 50,                       :null => false
    t.string   "color",           :limit => 6,  :default => "AB9364", :null => false
    t.integer  "topic_id"
    t.integer  "topic_count",                   :default => 0,        :null => false
    t.datetime "created_at",                                          :null => false
    t.datetime "updated_at",                                          :null => false
    t.integer  "user_id",                                             :null => false
    t.integer  "topics_year"
    t.integer  "topics_month"
    t.integer  "topics_week"
    t.string   "slug",                                                :null => false
    t.text     "description"
    t.string   "text_color",      :limit => 6,  :default => "FFFFFF", :null => false
    t.float    "hotness",                       :default => 5.0,      :null => false
    t.boolean  "read_restricted",               :default => false,    :null => false
    t.float    "auto_close_days"
  end

  add_index "categories", ["name"], :name => "index_categories_on_name", :unique => true
  add_index "categories", ["topic_count"], :name => "index_categories_on_forum_thread_count"

  create_table "category_featured_topics", :force => true do |t|
    t.integer  "category_id",                :null => false
    t.integer  "topic_id",                   :null => false
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
    t.integer  "rank",        :default => 0, :null => false
  end

  add_index "category_featured_topics", ["category_id", "rank"], :name => "index_category_featured_topics_on_category_id_and_rank"
  add_index "category_featured_topics", ["category_id", "topic_id"], :name => "cat_featured_threads", :unique => true

  create_table "category_featured_users", :force => true do |t|
    t.integer  "category_id"
    t.integer  "user_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "category_featured_users", ["category_id", "user_id"], :name => "index_category_featured_users_on_category_id_and_user_id", :unique => true

  create_table "category_groups", :force => true do |t|
    t.integer  "category_id",                    :null => false
    t.integer  "group_id",                       :null => false
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
    t.integer  "permission_type", :default => 1
  end

  create_table "category_search_data", :id => false, :force => true do |t|
    t.integer  "category_id", :null => false
    t.tsvector "search_data"
  end

  add_index "category_search_data", ["search_data"], :name => "idx_search_category"

  create_table "draft_sequences", :force => true do |t|
    t.integer "user_id",   :null => false
    t.string  "draft_key", :null => false
    t.integer "sequence",  :null => false
  end

  add_index "draft_sequences", ["user_id", "draft_key"], :name => "index_draft_sequences_on_user_id_and_draft_key", :unique => true

  create_table "drafts", :force => true do |t|
    t.integer  "user_id",                   :null => false
    t.string   "draft_key",                 :null => false
    t.text     "data",                      :null => false
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
    t.integer  "sequence",   :default => 0, :null => false
  end

  add_index "drafts", ["user_id", "draft_key"], :name => "index_drafts_on_user_id_and_draft_key"

  create_table "email_logs", :force => true do |t|
    t.string   "to_address",               :null => false
    t.string   "email_type",               :null => false
    t.integer  "user_id"
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
    t.string   "reply_key",  :limit => 32
    t.integer  "post_id"
    t.integer  "topic_id"
  end

  add_index "email_logs", ["created_at"], :name => "index_email_logs_on_created_at", :order => {"created_at"=>:desc}
  add_index "email_logs", ["reply_key"], :name => "index_email_logs_on_reply_key"
  add_index "email_logs", ["user_id", "created_at"], :name => "index_email_logs_on_user_id_and_created_at", :order => {"created_at"=>:desc}

  create_table "email_tokens", :force => true do |t|
    t.integer  "user_id",                       :null => false
    t.string   "email",                         :null => false
    t.string   "token",                         :null => false
    t.boolean  "confirmed",  :default => false, :null => false
    t.boolean  "expired",    :default => false, :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

  add_index "email_tokens", ["token"], :name => "index_email_tokens_on_token", :unique => true

  create_table "facebook_user_infos", :force => true do |t|
    t.integer  "user_id",                       :null => false
    t.integer  "facebook_user_id", :limit => 8, :null => false
    t.string   "username",                      :null => false
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.string   "gender"
    t.string   "name"
    t.string   "link"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

  add_index "facebook_user_infos", ["facebook_user_id"], :name => "index_facebook_user_infos_on_facebook_user_id", :unique => true
  add_index "facebook_user_infos", ["user_id"], :name => "index_facebook_user_infos_on_user_id", :unique => true

  create_table "github_user_infos", :force => true do |t|
    t.integer  "user_id",        :null => false
    t.string   "screen_name",    :null => false
    t.integer  "github_user_id", :null => false
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  add_index "github_user_infos", ["github_user_id"], :name => "index_github_user_infos_on_github_user_id", :unique => true
  add_index "github_user_infos", ["user_id"], :name => "index_github_user_infos_on_user_id", :unique => true

  create_table "group_users", :force => true do |t|
    t.integer  "group_id",   :null => false
    t.integer  "user_id",    :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "group_users", ["group_id", "user_id"], :name => "index_group_users_on_group_id_and_user_id", :unique => true

  create_table "groups", :force => true do |t|
    t.string   "name",                          :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "automatic",  :default => false, :null => false
    t.integer  "user_count", :default => 0,     :null => false
  end

  add_index "groups", ["name"], :name => "index_groups_on_name", :unique => true

  create_table "hot_topics", :force => true do |t|
    t.integer "topic_id",            :null => false
    t.integer "category_id"
    t.float   "score",               :null => false
    t.float   "random_bias"
    t.float   "random_multiplier"
    t.float   "days_ago_bias"
    t.float   "days_ago_multiplier"
    t.integer "hot_topic_type"
  end

  add_index "hot_topics", ["score"], :name => "index_hot_topics_on_score", :order => {"score"=>:desc}
  add_index "hot_topics", ["topic_id"], :name => "index_hot_topics_on_topic_id", :unique => true

  create_table "incoming_links", :force => true do |t|
    t.string   "url",             :limit => 1000, :null => false
    t.string   "referer",         :limit => 1000
    t.string   "domain",          :limit => 100
    t.integer  "topic_id"
    t.integer  "post_number"
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
    t.integer  "user_id"
    t.string   "ip_address",      :limit => nil
    t.integer  "current_user_id"
  end

  add_index "incoming_links", ["created_at", "domain"], :name => "index_incoming_links_on_created_at_and_domain"
  add_index "incoming_links", ["created_at", "user_id"], :name => "index_incoming_links_on_created_at_and_user_id"
  add_index "incoming_links", ["topic_id", "post_number"], :name => "incoming_index"

  create_table "invites", :force => true do |t|
    t.string   "invite_key",    :limit => 32, :null => false
    t.string   "email",                       :null => false
    t.integer  "invited_by_id",               :null => false
    t.integer  "user_id"
    t.datetime "redeemed_at"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
    t.datetime "deleted_at"
    t.integer  "deleted_by_id"
  end

  add_index "invites", ["email", "invited_by_id"], :name => "index_invites_on_email_and_invited_by_id", :unique => true
  add_index "invites", ["invite_key"], :name => "index_invites_on_invite_key", :unique => true

  create_table "message_bus", :force => true do |t|
    t.string   "name"
    t.string   "context"
    t.text     "data"
    t.datetime "created_at"
  end

  add_index "message_bus", ["created_at"], :name => "index_message_bus_on_created_at"

  create_table "notifications", :force => true do |t|
    t.integer  "notification_type",                                    :null => false
    t.integer  "user_id",                                              :null => false
    t.string   "data",              :limit => 1000,                    :null => false
    t.boolean  "read",                              :default => false, :null => false
    t.datetime "created_at",                                           :null => false
    t.datetime "updated_at",                                           :null => false
    t.integer  "topic_id"
    t.integer  "post_number"
    t.integer  "post_action_id"
  end

  add_index "notifications", ["post_action_id"], :name => "index_notifications_on_post_action_id"
  add_index "notifications", ["user_id", "created_at"], :name => "index_notifications_on_user_id_and_created_at"

  create_table "optimized_images", :force => true do |t|
    t.string  "sha1",      :limit => 40, :null => false
    t.string  "extension", :limit => 10, :null => false
    t.integer "width",                   :null => false
    t.integer "height",                  :null => false
    t.integer "upload_id",               :null => false
    t.string  "url",                     :null => false
  end

  add_index "optimized_images", ["upload_id", "width", "height"], :name => "index_optimized_images_on_upload_id_and_width_and_height", :unique => true
  add_index "optimized_images", ["upload_id"], :name => "index_optimized_images_on_upload_id"

  create_table "post_action_types", :force => true do |t|
    t.string   "name_key",   :limit => 50,                    :null => false
    t.boolean  "is_flag",                  :default => false, :null => false
    t.string   "icon",       :limit => 20
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
    t.integer  "position",                 :default => 0,     :null => false
  end

  create_table "post_actions", :force => true do |t|
    t.integer  "post_id",                                :null => false
    t.integer  "user_id",                                :null => false
    t.integer  "post_action_type_id",                    :null => false
    t.datetime "deleted_at"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.integer  "deleted_by_id"
    t.text     "message"
    t.integer  "related_post_id"
    t.boolean  "staff_took_action",   :default => false, :null => false
    t.boolean  "defer"
    t.integer  "defer_by"
  end

  add_index "post_actions", ["post_id"], :name => "index_post_actions_on_post_id"
  add_index "post_actions", ["user_id", "post_action_type_id", "post_id", "deleted_at"], :name => "idx_unique_actions", :unique => true

  create_table "post_replies", :id => false, :force => true do |t|
    t.integer  "post_id"
    t.integer  "reply_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "post_replies", ["post_id", "reply_id"], :name => "index_post_replies_on_post_id_and_reply_id", :unique => true

  create_table "post_search_data", :id => false, :force => true do |t|
    t.integer  "post_id",     :null => false
    t.tsvector "search_data"
  end

  add_index "post_search_data", ["search_data"], :name => "idx_search_post"

  create_table "post_timings", :id => false, :force => true do |t|
    t.integer "topic_id",    :null => false
    t.integer "post_number", :null => false
    t.integer "user_id",     :null => false
    t.integer "msecs",       :null => false
  end

  add_index "post_timings", ["topic_id", "post_number", "user_id"], :name => "post_timings_unique", :unique => true
  add_index "post_timings", ["topic_id", "post_number"], :name => "post_timings_summary"

  create_table "post_uploads", :force => true do |t|
    t.integer "post_id",   :null => false
    t.integer "upload_id", :null => false
  end

  add_index "post_uploads", ["post_id", "upload_id"], :name => "idx_unique_post_uploads", :unique => true

  create_table "posts", :force => true do |t|
    t.integer  "user_id",                                    :null => false
    t.integer  "topic_id",                                   :null => false
    t.integer  "post_number",                                :null => false
    t.text     "raw",                                        :null => false
    t.text     "cooked",                                     :null => false
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
    t.integer  "reply_to_post_number"
    t.integer  "cached_version",          :default => 1,     :null => false
    t.integer  "reply_count",             :default => 0,     :null => false
    t.integer  "quote_count",             :default => 0,     :null => false
    t.datetime "deleted_at"
    t.integer  "off_topic_count",         :default => 0,     :null => false
    t.integer  "like_count",              :default => 0,     :null => false
    t.integer  "incoming_link_count",     :default => 0,     :null => false
    t.integer  "bookmark_count",          :default => 0,     :null => false
    t.integer  "avg_time"
    t.float    "score"
    t.integer  "reads",                   :default => 0,     :null => false
    t.integer  "post_type",               :default => 1,     :null => false
    t.integer  "vote_count",              :default => 0,     :null => false
    t.integer  "sort_order"
    t.integer  "last_editor_id"
    t.boolean  "hidden",                  :default => false, :null => false
    t.integer  "hidden_reason_id"
    t.integer  "notify_moderators_count", :default => 0,     :null => false
    t.integer  "spam_count",              :default => 0,     :null => false
    t.integer  "illegal_count",           :default => 0,     :null => false
    t.integer  "inappropriate_count",     :default => 0,     :null => false
    t.datetime "last_version_at",                            :null => false
    t.boolean  "user_deleted",            :default => false, :null => false
    t.integer  "reply_to_user_id"
    t.float    "percent_rank",            :default => 1.0
    t.integer  "notify_user_count",       :default => 0,     :null => false
    t.integer  "like_score",              :default => 0,     :null => false
    t.integer  "deleted_by_id"
    t.boolean  "nuked_user",              :default => false
  end

  add_index "posts", ["reply_to_post_number"], :name => "index_posts_on_reply_to_post_number"
  add_index "posts", ["topic_id", "post_number"], :name => "index_posts_on_topic_id_and_post_number", :unique => true
  add_index "posts", ["user_id"], :name => "idx_posts_user_id_deleted_at"

  create_table "site_contents", :id => false, :force => true do |t|
    t.string   "content_type", :null => false
    t.text     "content",      :null => false
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  add_index "site_contents", ["content_type"], :name => "index_site_contents_on_content_type", :unique => true

  create_table "site_customizations", :force => true do |t|
    t.string   "name",                                      :null => false
    t.text     "stylesheet"
    t.text     "header"
    t.integer  "position",                                  :null => false
    t.integer  "user_id",                                   :null => false
    t.boolean  "enabled",                                   :null => false
    t.string   "key",                                       :null => false
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
    t.boolean  "override_default_style", :default => false, :null => false
    t.text     "stylesheet_baked",       :default => "",    :null => false
  end

  add_index "site_customizations", ["key"], :name => "index_site_customizations_on_key"

  create_table "site_settings", :force => true do |t|
    t.string   "name",       :null => false
    t.integer  "data_type",  :null => false
    t.text     "value"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "staff_action_logs", :force => true do |t|
    t.integer  "action",         :null => false
    t.integer  "staff_user_id",  :null => false
    t.integer  "target_user_id"
    t.text     "details"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.string   "context"
    t.string   "ip_address"
    t.string   "email"
  end

  create_table "topic_allowed_groups", :force => true do |t|
    t.integer "group_id", :null => false
    t.integer "topic_id", :null => false
  end

  add_index "topic_allowed_groups", ["group_id", "topic_id"], :name => "index_topic_allowed_groups_on_group_id_and_topic_id", :unique => true
  add_index "topic_allowed_groups", ["topic_id", "group_id"], :name => "index_topic_allowed_groups_on_topic_id_and_group_id", :unique => true

  create_table "topic_allowed_users", :force => true do |t|
    t.integer  "user_id",    :null => false
    t.integer  "topic_id",   :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "topic_allowed_users", ["topic_id", "user_id"], :name => "index_topic_allowed_users_on_topic_id_and_user_id", :unique => true
  add_index "topic_allowed_users", ["user_id", "topic_id"], :name => "index_topic_allowed_users_on_user_id_and_topic_id", :unique => true

  create_table "topic_invites", :force => true do |t|
    t.integer  "topic_id",   :null => false
    t.integer  "invite_id",  :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "topic_invites", ["invite_id"], :name => "index_topic_invites_on_invite_id"
  add_index "topic_invites", ["topic_id", "invite_id"], :name => "index_topic_invites_on_topic_id_and_invite_id", :unique => true

  create_table "topic_link_clicks", :force => true do |t|
    t.integer  "topic_link_id",                :null => false
    t.integer  "user_id"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
    t.string   "ip_address",    :limit => nil, :null => false
  end

  add_index "topic_link_clicks", ["topic_link_id"], :name => "by_link"

  create_table "topic_links", :force => true do |t|
    t.integer  "topic_id",                                        :null => false
    t.integer  "post_id"
    t.integer  "user_id",                                         :null => false
    t.string   "url",           :limit => 500,                    :null => false
    t.string   "domain",        :limit => 100,                    :null => false
    t.boolean  "internal",                     :default => false, :null => false
    t.integer  "link_topic_id"
    t.datetime "created_at",                                      :null => false
    t.datetime "updated_at",                                      :null => false
    t.boolean  "reflection",                   :default => false
    t.integer  "clicks",                       :default => 0,     :null => false
    t.integer  "link_post_id"
  end

  add_index "topic_links", ["topic_id", "post_id", "url"], :name => "unique_post_links", :unique => true
  add_index "topic_links", ["topic_id"], :name => "index_forum_thread_links_on_forum_thread_id"

  create_table "topic_users", :force => true do |t|
    t.integer  "user_id",                                     :null => false
    t.integer  "topic_id",                                    :null => false
    t.boolean  "starred",                  :default => false, :null => false
    t.boolean  "posted",                   :default => false, :null => false
    t.integer  "last_read_post_number"
    t.integer  "seen_post_count"
    t.datetime "starred_at"
    t.datetime "last_visited_at"
    t.datetime "first_visited_at"
    t.integer  "notification_level",       :default => 1,     :null => false
    t.datetime "notifications_changed_at"
    t.integer  "notifications_reason_id"
    t.integer  "total_msecs_viewed",       :default => 0,     :null => false
    t.datetime "cleared_pinned_at"
    t.datetime "unstarred_at"
  end

  add_index "topic_users", ["topic_id", "user_id"], :name => "index_forum_thread_users_on_forum_thread_id_and_user_id", :unique => true

  create_table "topics", :force => true do |t|
    t.string   "title",                                          :null => false
    t.datetime "last_posted_at"
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at",                                     :null => false
    t.integer  "views",                   :default => 0,         :null => false
    t.integer  "posts_count",             :default => 0,         :null => false
    t.integer  "user_id",                                        :null => false
    t.integer  "last_post_user_id",                              :null => false
    t.integer  "reply_count",             :default => 0,         :null => false
    t.integer  "featured_user1_id"
    t.integer  "featured_user2_id"
    t.integer  "featured_user3_id"
    t.integer  "avg_time"
    t.datetime "deleted_at"
    t.integer  "highest_post_number",     :default => 0,         :null => false
    t.string   "image_url"
    t.integer  "off_topic_count",         :default => 0,         :null => false
    t.integer  "like_count",              :default => 0,         :null => false
    t.integer  "incoming_link_count",     :default => 0,         :null => false
    t.integer  "bookmark_count",          :default => 0,         :null => false
    t.integer  "star_count",              :default => 0,         :null => false
    t.integer  "category_id"
    t.boolean  "visible",                 :default => true,      :null => false
    t.integer  "moderator_posts_count",   :default => 0,         :null => false
    t.boolean  "closed",                  :default => false,     :null => false
    t.boolean  "archived",                :default => false,     :null => false
    t.datetime "bumped_at",                                      :null => false
    t.boolean  "has_best_of",             :default => false,     :null => false
    t.hstore   "meta_data"
    t.integer  "vote_count",              :default => 0,         :null => false
    t.string   "archetype",               :default => "regular", :null => false
    t.integer  "featured_user4_id"
    t.integer  "notify_moderators_count", :default => 0,         :null => false
    t.integer  "spam_count",              :default => 0,         :null => false
    t.integer  "illegal_count",           :default => 0,         :null => false
    t.integer  "inappropriate_count",     :default => 0,         :null => false
    t.datetime "pinned_at"
    t.float    "score"
    t.float    "percent_rank",            :default => 1.0,       :null => false
    t.integer  "notify_user_count",       :default => 0,         :null => false
    t.string   "subtype"
    t.string   "slug"
    t.datetime "auto_close_at"
    t.integer  "auto_close_user_id"
    t.datetime "auto_close_started_at"
    t.integer  "deleted_by_id"
  end

  add_index "topics", ["bumped_at"], :name => "index_forum_threads_on_bumped_at", :order => {"bumped_at"=>:desc}
  add_index "topics", ["user_id"], :name => "idx_topics_user_id_deleted_at"

  create_table "twitter_user_infos", :force => true do |t|
    t.integer  "user_id",         :null => false
    t.string   "screen_name",     :null => false
    t.integer  "twitter_user_id", :null => false
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  add_index "twitter_user_infos", ["twitter_user_id"], :name => "index_twitter_user_infos_on_twitter_user_id", :unique => true
  add_index "twitter_user_infos", ["user_id"], :name => "index_twitter_user_infos_on_user_id", :unique => true

  create_table "uploads", :force => true do |t|
    t.integer  "user_id",                         :null => false
    t.string   "original_filename",               :null => false
    t.integer  "filesize",                        :null => false
    t.integer  "width"
    t.integer  "height"
    t.string   "url",                             :null => false
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
    t.string   "sha1",              :limit => 40
  end

  add_index "uploads", ["sha1"], :name => "index_uploads_on_sha1", :unique => true
  add_index "uploads", ["url"], :name => "index_uploads_on_url"
  add_index "uploads", ["user_id"], :name => "index_uploads_on_user_id"

  create_table "user_actions", :force => true do |t|
    t.integer  "action_type",     :null => false
    t.integer  "user_id",         :null => false
    t.integer  "target_topic_id"
    t.integer  "target_post_id"
    t.integer  "target_user_id"
    t.integer  "acting_user_id"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  add_index "user_actions", ["acting_user_id"], :name => "index_actions_on_acting_user_id"
  add_index "user_actions", ["action_type", "user_id", "target_topic_id", "target_post_id", "acting_user_id"], :name => "idx_unique_rows", :unique => true
  add_index "user_actions", ["user_id", "action_type"], :name => "index_actions_on_user_id_and_action_type"

  create_table "user_open_ids", :force => true do |t|
    t.integer  "user_id",    :null => false
    t.string   "email",      :null => false
    t.string   "url",        :null => false
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.boolean  "active",     :null => false
  end

  add_index "user_open_ids", ["url"], :name => "index_user_open_ids_on_url"

  create_table "user_search_data", :id => false, :force => true do |t|
    t.integer  "user_id",     :null => false
    t.tsvector "search_data"
  end

  add_index "user_search_data", ["search_data"], :name => "idx_search_user"

  create_table "user_visits", :force => true do |t|
    t.integer "user_id",    :null => false
    t.date    "visited_at", :null => false
  end

  add_index "user_visits", ["user_id", "visited_at"], :name => "index_user_visits_on_user_id_and_visited_at", :unique => true

  create_table "users", :force => true do |t|
    t.string   "username",                      :limit => 20,                     :null => false
    t.datetime "created_at",                                                      :null => false
    t.datetime "updated_at",                                                      :null => false
    t.string   "name"
    t.text     "bio_raw"
    t.integer  "seen_notification_id",                         :default => 0,     :null => false
    t.datetime "last_posted_at"
    t.string   "email",                         :limit => 256,                    :null => false
    t.string   "password_hash",                 :limit => 64
    t.string   "salt",                          :limit => 32
    t.boolean  "active"
    t.string   "username_lower",                :limit => 20,                     :null => false
    t.string   "auth_token",                    :limit => 32
    t.datetime "last_seen_at"
    t.string   "website"
    t.boolean  "admin",                                        :default => false, :null => false
    t.datetime "last_emailed_at"
    t.boolean  "email_digests",                                :default => true,  :null => false
    t.integer  "trust_level",                                                     :null => false
    t.text     "bio_cooked"
    t.boolean  "email_private_messages",                       :default => true
    t.boolean  "email_direct",                                 :default => true,  :null => false
    t.boolean  "approved",                                     :default => false, :null => false
    t.integer  "approved_by_id"
    t.datetime "approved_at"
    t.integer  "topics_entered",                               :default => 0,     :null => false
    t.integer  "posts_read_count",                             :default => 0,     :null => false
    t.integer  "digest_after_days",                            :default => 7,     :null => false
    t.datetime "previous_visit_at"
    t.datetime "banned_at"
    t.datetime "banned_till"
    t.date     "date_of_birth"
    t.integer  "auto_track_topics_after_msecs"
    t.integer  "views",                                        :default => 0,     :null => false
    t.integer  "flag_level",                                   :default => 0,     :null => false
    t.integer  "time_read",                                    :default => 0,     :null => false
    t.integer  "days_visited",                                 :default => 0,     :null => false
    t.string   "ip_address",                    :limit => nil
    t.integer  "new_topic_duration_minutes"
    t.boolean  "external_links_in_new_tab",                    :default => false, :null => false
    t.boolean  "enable_quoting",                               :default => true,  :null => false
    t.boolean  "moderator",                                    :default => false
    t.integer  "likes_given",                                  :default => 0,     :null => false
    t.integer  "likes_received",                               :default => 0,     :null => false
    t.integer  "topic_reply_count",                            :default => 0,     :null => false
    t.boolean  "blocked",                                      :default => false
    t.boolean  "dynamic_favicon",                              :default => false, :null => false
    t.string   "title"
  end

  add_index "users", ["auth_token"], :name => "index_users_on_auth_token"
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["last_posted_at"], :name => "index_users_on_last_posted_at"
  add_index "users", ["username"], :name => "index_users_on_username", :unique => true
  add_index "users", ["username_lower"], :name => "index_users_on_username_lower", :unique => true

  create_table "versions", :force => true do |t|
    t.integer  "versioned_id"
    t.string   "versioned_type"
    t.integer  "user_id"
    t.string   "user_type"
    t.string   "user_name"
    t.text     "modifications"
    t.integer  "number"
    t.integer  "reverted_from"
    t.string   "tag"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  add_index "versions", ["created_at"], :name => "index_versions_on_created_at"
  add_index "versions", ["number"], :name => "index_versions_on_number"
  add_index "versions", ["tag"], :name => "index_versions_on_tag"
  add_index "versions", ["user_id", "user_type"], :name => "index_versions_on_user_id_and_user_type"
  add_index "versions", ["user_name"], :name => "index_versions_on_user_name"
  add_index "versions", ["versioned_id", "versioned_type"], :name => "index_versions_on_versioned_id_and_versioned_type"

  create_table "views", :id => false, :force => true do |t|
    t.integer "parent_id",                  :null => false
    t.string  "parent_type", :limit => 50,  :null => false
    t.date    "viewed_at",                  :null => false
    t.integer "user_id"
    t.string  "ip_address",  :limit => nil, :null => false
  end

  add_index "views", ["parent_id", "parent_type"], :name => "index_views_on_parent_id_and_parent_type"

end
