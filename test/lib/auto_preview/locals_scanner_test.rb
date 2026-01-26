# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class LocalsScannerTest < ActiveSupport::TestCase
    def test_scans_template_for_render_calls_with_locals
      scanner = LocalsScanner.new(
        view_paths: [File.expand_path("../../../app/views", __dir__)]
      )

      # The dashboard template renders user_profile with user_name and user_email
      locals = scanner.locals_for("pages/_user_profile.html.erb")

      assert_includes locals, "user_email"
      assert_includes locals, "user_name"
    end

    def test_returns_empty_array_for_template_without_known_locals
      scanner = LocalsScanner.new(
        view_paths: [File.expand_path("../../../app/views", __dir__)]
      )

      # home.html.erb is not rendered with locals anywhere
      locals = scanner.locals_for("pages/home.html.erb")

      assert_equal [], locals
    end

    def test_handles_nonexistent_view_path
      scanner = LocalsScanner.new(
        view_paths: ["/nonexistent/path"]
      )

      locals = scanner.locals_for("pages/home.html.erb")

      assert_equal [], locals
    end

    def test_template_path_conversion
      scanner = LocalsScanner.new(view_paths: [])

      # Test that different path formats work
      assert_equal [], scanner.locals_for("pages/home.html.erb")
      assert_equal [], scanner.locals_for("pages/home")
    end

    def test_caches_template_locals
      scanner = LocalsScanner.new(
        view_paths: [File.expand_path("../../../app/views", __dir__)]
      )

      # Call twice to test caching
      locals1 = scanner.template_locals
      locals2 = scanner.template_locals

      assert_same locals1, locals2
    end

    def test_handles_controller_paths
      scanner = LocalsScanner.new(
        view_paths: [],
        controller_paths: ["/nonexistent/controllers"]
      )

      # Should not raise, just return empty
      locals = scanner.locals_for("pages/home.html.erb")
      assert_equal [], locals
    end

    def test_scans_controller_directory_for_render_calls
      # Create a temporary controller that renders a partial with locals
      Dir.mktmpdir do |tmpdir|
        controller_content = <<~RUBY
          class TestController < ActionController::Base
            def show
              render partial: "items/item", locals: { item: @item, show_details: true }
            end
          end
        RUBY
        File.write(File.join(tmpdir, "test_controller.rb"), controller_content)

        scanner = LocalsScanner.new(
          view_paths: [],
          controller_paths: [tmpdir]
        )

        locals = scanner.locals_for("items/_item.html.erb")

        assert_includes locals, "item"
        assert_includes locals, "show_details"
      end
    end

    def test_locals_for_with_non_partial_path
      scanner = LocalsScanner.new(
        view_paths: [File.expand_path("../../../app/views", __dir__)]
      )

      # Test non-partial version (pages/user_profile vs pages/_user_profile)
      locals = scanner.locals_for("pages/user_profile.html.erb")

      # Should still find locals via partialize
      assert_includes locals, "user_email"
      assert_includes locals, "user_name"
    end

    def test_partialize_already_partial
      scanner = LocalsScanner.new(view_paths: [])

      # When path already starts with underscore, partialize should keep it
      result = scanner.partialize("pages/_already_partial")

      assert_equal "pages/_already_partial", result
    end

    def test_partialize_non_partial
      scanner = LocalsScanner.new(view_paths: [])

      # When path doesn't start with underscore, partialize should add it
      result = scanner.partialize("pages/not_partial")

      assert_equal "pages/_not_partial", result
    end

    def test_partialize_empty_path
      scanner = LocalsScanner.new(view_paths: [])

      # Empty path should return early
      result = scanner.partialize("")

      assert_equal "", result
    end

    def test_template_path_without_double_extension
      scanner = LocalsScanner.new(view_paths: [])

      # Test path with only one extension
      result = scanner.template_path_to_virtual_path("pages/home.erb")

      assert_equal "pages/home", result
    end

    def test_template_path_no_extension
      scanner = LocalsScanner.new(view_paths: [])

      # Test path with no extension at all
      result = scanner.template_path_to_virtual_path("pages/home")

      assert_equal "pages/home", result
    end

    def test_locals_for_direct_virtual_path_match
      # Create a template that is rendered directly (not as a partial)
      Dir.mktmpdir do |tmpdir|
        # Create a view that renders "items/list" (non-partial) with locals
        FileUtils.mkdir_p(File.join(tmpdir, "pages"))
        template_content = <<~ERB
          <h1>Container</h1>
          <%= render template: "items/list", locals: { items: @items, title: "My List" } %>
        ERB
        File.write(File.join(tmpdir, "pages/container.html.erb"), template_content)

        scanner = LocalsScanner.new(view_paths: [tmpdir])

        # "items/list" should be found directly (not partialize'd)
        locals = scanner.locals_for("items/list.html.erb")

        assert_includes locals, "items"
        assert_includes locals, "title"
      end
    end

    def test_template_path_to_virtual_path_with_double_extension
      scanner = LocalsScanner.new(view_paths: [])

      # Test path with double extension like .html.erb
      result = scanner.template_path_to_virtual_path("pages/home.html.erb")

      assert_equal "pages/home", result
    end
  end
end
