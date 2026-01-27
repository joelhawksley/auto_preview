# frozen_string_literal: true

# Separate test file for CoverageTracker that runs WITHOUT SimpleCov
# Run with: ruby test/standalone/coverage_tracker_test.rb

# Don't load SimpleCov for this test
ENV["RAILS_ENV"] = "development"  # Use development to enable coverage tracking

require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "active_record/railtie"

require "auto_preview"

# Minimal Rails application for testing
class CoverageTestApp < Rails::Application
  config.eager_load = false
  config.hosts.clear
  config.secret_key_base = "test_secret_key_base"
  config.active_record.maintain_test_schema = false
end

Rails.application.initialize!

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

require "minitest/autorun"

module AutoPreview
  class CoverageTrackerTest < Minitest::Test
    def test_track_returns_coverage_data_for_template
      # Create a temporary template file
      template_content = <<~ERB
        <h1>Hello</h1>
        <% if true %>
          <p>Visible</p>
        <% else %>
          <p>Hidden</p>
        <% end %>
      ERB

      Dir.mktmpdir do |tmpdir|
        template_path = "test_template.html.erb"
        full_path = File.join(tmpdir, template_path)
        File.write(full_path, template_content)

        # Use ERB with filename set for eval coverage to work
        erb = ERB.new(File.read(full_path))
        erb.filename = full_path

        coverage, result = CoverageTracker.track(template_path, [tmpdir]) do
          erb.result(binding)
        end

        assert_kind_of Hash, coverage
        assert_kind_of String, result
      end
    end

    def test_track_returns_empty_coverage_when_template_not_found
      coverage, result = CoverageTracker.track("nonexistent.html.erb", ["/tmp"]) do
        "rendered"
      end

      assert_equal({}, coverage)
      assert_equal "rendered", result
    end

    def test_extract_template_coverage_with_executed_lines
      coverage_data = {
        "/app/views/pages/home.html.erb" => {lines: [1, nil, 0, 2, nil]}
      }

      result = CoverageTracker.send(
        :extract_template_coverage,
        coverage_data,
        "/app/views/pages/home.html.erb",
        "pages/home.html.erb"
      )

      # Line 1: executed once (covered)
      # Line 2: nil (not executable)
      # Line 3: never executed (uncovered)
      # Line 4: executed twice (covered)
      # Line 5: nil (not executable)
      assert_equal true, result[1]
      assert_nil result[2]
      assert_equal false, result[3]
      assert_equal true, result[4]
      assert_nil result[5]
    end

    def test_extract_template_coverage_with_array_format
      # Some Ruby versions return array instead of hash
      coverage_data = {
        "/app/views/pages/home.html.erb" => [1, nil, 0, 1, nil]
      }

      result = CoverageTracker.send(
        :extract_template_coverage,
        coverage_data,
        "/app/views/pages/home.html.erb",
        "pages/home.html.erb"
      )

      assert_equal({1 => true, 3 => false, 4 => true}, result)
    end

    def test_extract_template_coverage_matches_by_template_path_suffix
      coverage_data = {
        "/some/other/path/pages/home.html.erb" => {lines: [1, 1]}
      }

      result = CoverageTracker.send(
        :extract_template_coverage,
        coverage_data,
        "/app/views/pages/home.html.erb",
        "pages/home.html.erb"
      )

      assert_equal({1 => true, 2 => true}, result)
    end

    def test_extract_template_coverage_returns_empty_when_no_match
      coverage_data = {
        "/other/file.rb" => {lines: [1, 1, 1]}
      }

      result = CoverageTracker.send(
        :extract_template_coverage,
        coverage_data,
        "/app/views/pages/home.html.erb",
        "pages/home.html.erb"
      )

      assert_equal({}, result)
    end

    def test_extract_template_coverage_skips_nil_data
      coverage_data = {
        "/app/views/pages/home.html.erb" => {lines: nil}
      }

      result = CoverageTracker.send(
        :extract_template_coverage,
        coverage_data,
        "/app/views/pages/home.html.erb",
        "pages/home.html.erb"
      )

      assert_equal({}, result)
    end

    def test_track_skips_in_test_environment
      original_env = ENV["RAILS_ENV"]
      ENV["RAILS_ENV"] = "test"

      begin
        Dir.mktmpdir do |tmpdir|
          template_path = "skip_test.html.erb"
          File.write(File.join(tmpdir, template_path), "<%= 'hello' %>")

          coverage, result = CoverageTracker.track(template_path, [tmpdir]) do
            "test result"
          end

          assert_equal({}, coverage)
          assert_equal "test result", result
        end
      ensure
        ENV["RAILS_ENV"] = original_env
      end
    end
  end
end
