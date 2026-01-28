# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  enable_coverage :branch
  minimum_coverage line: 100, branch: 99
end

ENV["RAILS_ENV"] = "test"

require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "active_record/railtie"

require "view_component"
require "auto_preview"
require "factory_bot_rails"

# Dummy Rails application for testing
class DummyApp < Rails::Application
  config.eager_load = false
  config.hosts << "www.example.com"
  config.hosts << "127.0.0.1"
  config.hosts << "localhost"
  config.secret_key_base = "test_secret_key_base_for_auto_preview_gem"
  config.active_record.maintain_test_schema = false
  config.view_component.view_component_path = "app/components"
end

# Configure AutoPreview to use the host app's ApplicationController
AutoPreview.parent_controller = "ApplicationController"

Rails.application.initialize!

# Set up in-memory SQLite database
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.timestamps
  end
end

# Load the User model
require_relative "../app/models/user"

Rails.application.routes.draw do
  mount AutoPreview::Engine => "/auto_preview"

  get "pages/home", to: "pages#home"
  get "pages/about", to: "pages#about"
end

require "minitest/autorun"
require "rails/test_help"
require "capybara/minitest"
require "selenium-webdriver"

# Register headless Chrome driver
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1000")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Configure Capybara defaults
Capybara.default_driver = :headless_chrome
Capybara.javascript_driver = :headless_chrome
Capybara.server = :puma, {Silent: true}
Capybara.default_max_wait_time = 5
Capybara.server_host = "127.0.0.1"

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
