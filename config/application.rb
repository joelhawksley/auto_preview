# frozen_string_literal: true

require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

require "auto_preview"

module DevelopmentApp
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "development_secret_key_base_for_auto_preview_gem"
    config.hosts.clear

    # Use separate routes file for the development app
    config.paths["config/routes.rb"] = ["config/app_routes.rb"]

    # Add test views for development preview
    config.paths["app/views"] << File.expand_path("../test/views", __dir__)
  end
end
