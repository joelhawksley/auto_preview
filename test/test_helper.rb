# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100
end

ENV["RAILS_ENV"] = "test"

require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"

require "auto_preview"

# Dummy Rails application for testing
class DummyApp < Rails::Application
  config.eager_load = false
  config.hosts << "www.example.com"
  config.secret_key_base = "test_secret_key_base_for_auto_preview_gem"
end

# Configure AutoPreview to use the host app's ApplicationController
AutoPreview.parent_controller = "ApplicationController"

Rails.application.initialize!

Rails.application.routes.draw do
  mount AutoPreview::Engine => "/auto_preview"

  get "pages/home", to: "pages#home"
  get "pages/about", to: "pages#about"
end

require "minitest/autorun"
require "rails/test_help"
require "capybara/minitest"

class SystemTestCase < ActionDispatch::IntegrationTest
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    Capybara.app = Rails.application
  end

  def teardown
    Capybara.reset_sessions!
  end
end
