# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class PreviewsControllerTest < ActionDispatch::IntegrationTest
    def test_index_renders_template_selector
      get "/auto_preview"

      assert_response :success
      assert_includes response.body, "<h1>AutoPreview</h1>"
      assert_includes response.body, "<select"
      assert_includes response.body, "pages/home.html.erb"
      assert_includes response.body, "pages/about.html.erb"
    end

    def test_index_excludes_layouts
      get "/auto_preview"

      assert_response :success
      refute_includes response.body, "layouts/application"
    end

    def test_show_renders_selected_template
      get "/auto_preview/show", params: { template: "pages/home.html.erb" }

      assert_response :success
      assert_includes response.body, "<h1>Home Page</h1>"
    end

    def test_show_renders_template_using_application_helper
      get "/auto_preview/show", params: {
        template: "pages/with_helper.html.erb",
        vars: { name: { type: "String", value: "World" } }
      }

      assert_response :success
      assert_includes response.body, "Hello, World! Welcome to the app."
    end

    def test_show_returns_not_found_for_missing_template
      get "/auto_preview/show", params: { template: "nonexistent/template" }

      assert_response :not_found
      assert_includes response.body, "Template not found"
    end

    def test_show_returns_not_found_for_blank_template
      get "/auto_preview/show", params: { template: "" }

      assert_response :not_found
    end

    def test_show_returns_not_found_without_template_param
      get "/auto_preview/show"

      assert_response :not_found
    end

    def test_show_prompts_for_missing_variable
      get "/auto_preview/show", params: { template: "pages/greeting.html.erb" }

      assert_response :success
      assert_includes response.body, "Missing Variable"
      assert_includes response.body, "name"
      assert_includes response.body, "vars[name][type]"
      assert_includes response.body, "vars[name][value]"
    end

    def test_show_renders_template_with_string_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "String", value: "Alice" } }
      }

      assert_response :success
      assert_includes response.body, "Hello, Alice!"
    end

    def test_show_renders_template_with_integer_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "Integer", value: "42" } }
      }

      assert_response :success
      assert_includes response.body, "Hello, 42!"
    end

    def test_show_renders_template_with_float_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "Float", value: "3.14" } }
      }

      assert_response :success
      assert_includes response.body, "Hello, 3.14!"
    end

    def test_show_renders_template_with_boolean_true_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "Boolean", value: "true" } }
      }

      assert_response :success
      assert_includes response.body, "Hello, true!"
    end

    def test_show_renders_template_with_boolean_false_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "Boolean", value: "false" } }
      }

      assert_response :success
      assert_includes response.body, "Hello, false!"
    end

    def test_show_renders_template_with_nil_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "NilClass", value: "" } }
      }

      assert_response :success
      assert_includes response.body, "Hello, !"
    end

    def test_show_renders_template_with_array_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "Array", value: '["a", "b", "c"]' } }
      }

      assert_response :success
      # HTML-escapes quotes in the output
      assert_includes response.body, "Hello, ["
      assert_includes response.body, "a"
    end

    def test_show_renders_template_with_hash_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: { name: { type: "Hash", value: '{"key": "value"}' } }
      }

      assert_response :success
      # HTML-escapes quotes in the output
      assert_includes response.body, "Hello, {"
      assert_includes response.body, "key"
    end

    def test_show_preserves_existing_vars_in_form
      # First request triggers the form
      get "/auto_preview/show", params: {
        template: "pages/multi_var.html.erb",
        vars: { first_var: { type: "String", value: "hello" } }
      }

      assert_response :success
      # Should show the form for the next missing variable
      # and preserve the existing var in hidden fields
      assert_includes response.body, "first_var"
      assert_includes response.body, "second_var"
    end

    def test_show_renders_multi_var_template_with_all_vars
      get "/auto_preview/show", params: {
        template: "pages/multi_var.html.erb",
        vars: {
          first_var: { type: "String", value: "hello" },
          second_var: { type: "String", value: "world" }
        }
      }

      assert_response :success
      assert_includes response.body, "First: hello"
      assert_includes response.body, "Second: world"
    end

    def test_show_handles_empty_vars_param
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {}
      }

      assert_response :success
      assert_includes response.body, "Missing Variable"
    end

    def test_show_handles_invalid_vars_format
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: "invalid"
      }

      assert_response :success
      assert_includes response.body, "Missing Variable"
    end

    def test_show_raises_non_name_error_template_errors
      get "/auto_preview/show", params: { template: "pages/error_test.html.erb" }

      # Non-NameError template errors should propagate and result in server error
      assert_response :internal_server_error
    end

    def test_show_prompts_for_locals_detected_via_scanning
      # The _user_profile partial is rendered with user_name and user_email in dashboard.html.erb
      # The scanner should detect these and prompt before trying to render
      get "/auto_preview/show", params: { template: "pages/_user_profile.html.erb" }

      assert_response :success
      assert_includes response.body, "Missing Variable"
      # Should prompt for one of the detected locals
      assert(response.body.include?("user_name") || response.body.include?("user_email"))
    end

    def test_show_renders_partial_with_scanned_locals_provided
      get "/auto_preview/show", params: {
        template: "pages/_user_profile.html.erb",
        vars: {
          user_name: { type: "String", value: "John Doe" },
          user_email: { type: "String", value: "john@example.com" }
        }
      }

      assert_response :success
      assert_includes response.body, "John Doe"
      assert_includes response.body, "john@example.com"
    end

    def test_show_prompts_for_remaining_locals_when_some_already_provided
      # Provide only user_name but not user_email
      # This should trigger prompt_for_local with existing vars (a hash)
      # covering the THEN branch of `existing.respond_to?(:keys) ? existing : {}`
      get "/auto_preview/show", params: {
        template: "pages/_user_profile.html.erb",
        vars: {
          user_name: { type: "String", value: "Jane Doe" }
        }
      }

      assert_response :success
      assert_includes response.body, "Missing Variable"
      # Should prompt for the missing user_email
      assert_includes response.body, "user_email"
      # The existing var should be preserved in the form
      assert_includes response.body, "Jane Doe"
    end
  end

  class PreviewsControllerUnitTest < ActiveSupport::TestCase
    def test_find_erb_files_returns_empty_when_views_path_missing
      controller = PreviewsController.new
      temp_dir = Dir.mktmpdir

      controller.stub(:view_paths, [File.join(temp_dir, "nonexistent")]) do
        result = controller.send(:find_erb_files)
        assert_equal [], result
      end
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir
    end

    def test_coerce_value_string
      controller = PreviewsController.new
      assert_equal "hello", controller.send(:coerce_value, "hello", "String")
      assert_equal "123", controller.send(:coerce_value, 123, "String")
    end

    def test_coerce_value_integer
      controller = PreviewsController.new
      assert_equal 42, controller.send(:coerce_value, "42", "Integer")
      assert_equal 0, controller.send(:coerce_value, "not a number", "Integer")
    end

    def test_coerce_value_float
      controller = PreviewsController.new
      assert_equal 3.14, controller.send(:coerce_value, "3.14", "Float")
      assert_equal 0.0, controller.send(:coerce_value, "not a number", "Float")
    end

    def test_coerce_value_boolean
      controller = PreviewsController.new
      assert_equal true, controller.send(:coerce_value, "true", "Boolean")
      assert_equal true, controller.send(:coerce_value, "1", "Boolean")
      assert_equal true, controller.send(:coerce_value, "yes", "Boolean")
      assert_equal true, controller.send(:coerce_value, "YES", "Boolean")
      assert_equal false, controller.send(:coerce_value, "false", "Boolean")
      assert_equal false, controller.send(:coerce_value, "anything", "Boolean")
    end

    def test_coerce_value_array
      controller = PreviewsController.new
      assert_equal ["a", "b"], controller.send(:coerce_value, '["a", "b"]', "Array")
      assert_equal [], controller.send(:coerce_value, "invalid json", "Array")
      assert_equal [], controller.send(:coerce_value, "", "Array")
    end

    def test_coerce_value_hash
      controller = PreviewsController.new
      assert_equal({ "key" => "value" }, controller.send(:coerce_value, '{"key": "value"}', "Hash"))
      assert_equal({}, controller.send(:coerce_value, "invalid json", "Hash"))
      assert_equal({}, controller.send(:coerce_value, "", "Hash"))
    end

    def test_coerce_value_nil
      controller = PreviewsController.new
      assert_nil controller.send(:coerce_value, "anything", "NilClass")
    end

    def test_coerce_value_unknown_type_defaults_to_string
      controller = PreviewsController.new
      assert_equal "hello", controller.send(:coerce_value, "hello", "UnknownType")
    end

    def test_handle_name_error_raises_for_non_matching_error
      controller = PreviewsController.new
      controller.params = ActionController::Parameters.new({})

      # Create a NameError with an unexpected message format
      error = NameError.new("some other error message")

      assert_raises(NameError) do
        controller.send(:handle_name_error, error, "pages/test.html.erb")
      end
    end

    def test_build_locals_skips_invalid_config_format
      controller = PreviewsController.new
      controller.params = ActionController::Parameters.new({
        vars: { name: "just a string, not a hash" }
      })

      result = controller.send(:build_locals_from_params)
      assert_equal({}, result)
    end
  end

  class LocalsScannerTest < ActiveSupport::TestCase
    def test_scans_template_for_render_calls_with_locals
      scanner = LocalsScanner.new(
        view_paths: [File.expand_path("../../views", __dir__)]
      )

      # The dashboard template renders user_profile with user_name and user_email
      locals = scanner.locals_for("pages/_user_profile.html.erb")

      assert_includes locals, "user_email"
      assert_includes locals, "user_name"
    end

    def test_returns_empty_array_for_template_without_known_locals
      scanner = LocalsScanner.new(
        view_paths: [File.expand_path("../../views", __dir__)]
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
        view_paths: [File.expand_path("../../views", __dir__)]
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
        view_paths: [File.expand_path("../../views", __dir__)]
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
      # This tests the branch where parts[-1].start_with?("_") is true
      result = scanner.send(:partialize, "pages/_already_partial")

      assert_equal "pages/_already_partial", result
    end

    def test_partialize_non_partial
      scanner = LocalsScanner.new(view_paths: [])

      # When path doesn't start with underscore, partialize should add it
      result = scanner.send(:partialize, "pages/not_partial")

      assert_equal "pages/_not_partial", result
    end

    def test_partialize_empty_path
      scanner = LocalsScanner.new(view_paths: [])

      # Empty path should return early
      result = scanner.send(:partialize, "")

      assert_equal "", result
    end

    def test_template_path_without_double_extension
      scanner = LocalsScanner.new(view_paths: [])

      # Test path with only one extension
      result = scanner.send(:template_path_to_virtual_path, "pages/home.erb")

      assert_equal "pages/home", result
    end

    def test_template_path_no_extension
      scanner = LocalsScanner.new(view_paths: [])

      # Test path with no extension at all
      result = scanner.send(:template_path_to_virtual_path, "pages/home")

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
      # The regex removes everything from the first dot to the end
      result = scanner.send(:template_path_to_virtual_path, "pages/home.html.erb")

      assert_equal "pages/home", result
    end

    def test_engine_recreates_controller_on_reload
      # Simulate code reloading by triggering to_prepare again
      # This should remove and recreate the PreviewsController constant
      assert AutoPreview.const_defined?(:PreviewsController, false)

      # Trigger the to_prepare callback manually
      Rails.application.reloader.prepare!

      # Controller should still exist and work
      assert AutoPreview.const_defined?(:PreviewsController, false)
      assert AutoPreview::PreviewsController < ApplicationController
    end

    def test_engine_creates_controller_when_not_defined
      # Test the else branch - when PreviewsController doesn't exist yet
      # Remove it first
      AutoPreview.send(:remove_const, :PreviewsController)
      refute AutoPreview.const_defined?(:PreviewsController, false)

      # Trigger to_prepare - should create the controller
      Rails.application.reloader.prepare!

      # Controller should now exist
      assert AutoPreview.const_defined?(:PreviewsController, false)
      assert AutoPreview::PreviewsController < ApplicationController
    end
  end
end
