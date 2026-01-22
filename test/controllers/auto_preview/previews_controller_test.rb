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
end
