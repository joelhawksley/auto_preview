# frozen_string_literal: true

require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "active_record/railtie"

require "auto_preview"
require "factory_bot_rails"

module DevelopmentApp
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "development_secret_key_base_for_auto_preview_gem"
    config.hosts.clear

    # Configure database for FactoryBot support
    config.active_record.maintain_test_schema = false

    # Use separate routes file for the development app
    config.paths["config/routes.rb"] = ["config/app_routes.rb"]

    # Add test views for development preview
    config.paths["app/views"] << File.expand_path("../test/views", __dir__)
  end
end
