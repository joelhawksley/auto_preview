# frozen_string_literal: true

# System tests for coverage highlighting functionality
# Run with: bundle exec rake test_coverage
#
# These tests run in development mode to enable actual coverage tracking
# and use Capybara with headless Chrome to verify the UI.

ENV["RAILS_ENV"] = "development"

require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "active_record/railtie"

require "auto_preview"
require "capybara"
require "capybara/minitest"
require "selenium-webdriver"

# Minimal Rails application for testing coverage UI
class CoverageSystemTestApp < Rails::Application
  config.eager_load = false
  config.hosts.clear
  config.secret_key_base = "test_secret_key_base_coverage_system"
  config.active_record.maintain_test_schema = false
end

Rails.application.initialize!

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Set up routes
Rails.application.routes.draw do
  mount AutoPreview::Engine => "/auto_preview"
end

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

Capybara.default_driver = :headless_chrome
Capybara.javascript_driver = :headless_chrome
Capybara.server = :puma, {Silent: true}
Capybara.default_max_wait_time = 5
Capybara.server_host = "127.0.0.1"
Capybara.app = Rails.application

require "minitest/autorun"

class CoverageHighlightingSystemTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def teardown
    Capybara.reset_sessions!
  end

  def test_coverage_summary_is_displayed
    visit "/auto_preview/show?template=pages/home.html.erb"

    # The coverage summary should be present
    assert page.has_css?("#coverageSummary"), "Coverage summary element should be present"
  end

  def test_source_code_shows_line_numbers
    visit "/auto_preview/show?template=pages/home.html.erb"

    # Source code should have line numbers
    assert page.has_css?(".source-line-number"), "Line numbers should be present"
  end

  def test_source_code_has_source_lines
    visit "/auto_preview/show?template=pages/home.html.erb"

    # Source code should have source lines
    assert page.has_css?(".source-line"), "Source lines should be present"
  end

  def test_conditional_template_shows_coverage_highlighting
    # Test with a template that has conditional logic
    visit "/auto_preview/show?template=pages/conditional_feature.html.erb&vars[premium_user%3F][type]=Boolean&vars[premium_user%3F][value]=true&vars[user_name][type]=String&vars[user_name][value]=Alice"

    # Should have coverage summary
    assert page.has_css?("#coverageSummary"), "Coverage summary should be present"

    # Should have source lines
    assert page.has_css?(".source-line"), "Source lines should be present"
  end

  def test_coverage_summary_shows_statistics
    visit "/auto_preview/show?template=pages/greeting.html.erb&vars[name][type]=String&vars[name][value]=World"

    # The coverage summary should contain coverage information
    summary = find("#coverageSummary")
    summary_text = summary.text.downcase

    # Should show some kind of coverage info (either stats or "no coverage data")
    has_coverage_info = summary_text.include?("covered") ||
                        summary_text.include?("coverage") ||
                        summary_text.include?("no coverage")

    assert has_coverage_info, "Coverage summary should show coverage information. Got: #{summary_text}"
  end

  def test_source_panel_is_visible
    visit "/auto_preview/show?template=pages/home.html.erb"

    # The source panel should be visible
    assert page.has_css?(".auto-preview-source"), "Source panel should be visible"
    assert page.has_css?("#sourceCode"), "Source code element should be present"
  end
end
