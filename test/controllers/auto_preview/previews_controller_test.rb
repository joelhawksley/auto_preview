# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class PreviewsControllerTest < ActionDispatch::IntegrationTest
    # Helper to check if text appears in the iframe srcdoc
    def assert_preview_includes(text)
      # The content is injected raw into the srcdoc attribute (with quotes escaped)
      assert_includes response.body, text, "Expected preview iframe to include '#{text}'"
    end

    # Helper to check content is NOT in iframe srcdoc
    def refute_preview_includes(text)
      refute_includes response.body, text, "Expected preview iframe NOT to include '#{text}'"
    end

    def test_index_renders_template_selector
      get "/auto_preview"

      assert_response :success
      assert_includes response.body, "<h1>AutoPreview</h1>"
      assert_includes response.body, "auto-preview-filtered-dropdown"
      assert_includes response.body, "pages/home.html.erb"
      assert_includes response.body, "pages/about.html.erb"
    end

    def test_index_excludes_layouts
      get "/auto_preview"

      assert_response :success
      refute_includes response.body, "layouts/application"
    end

    def test_show_renders_selected_template
      get "/auto_preview/show", params: {template: "pages/home.html.erb"}

      assert_response :success
      assert_preview_includes "<h1>Home Page</h1>"
    end

    def test_show_renders_template_using_application_helper
      get "/auto_preview/show", params: {
        template: "pages/with_helper.html.erb",
        vars: {name: {type: "String", value: "World"}}
      }

      assert_response :success
      assert_preview_includes "Hello, World! Welcome to the app."
    end

    def test_show_returns_not_found_for_missing_template
      get "/auto_preview/show", params: {template: "nonexistent/template"}

      assert_response :not_found
      assert_includes response.body, "Template not found"
    end

    def test_show_returns_not_found_for_blank_template
      get "/auto_preview/show", params: {template: ""}

      assert_response :not_found
    end

    def test_show_returns_not_found_without_template_param
      get "/auto_preview/show"

      assert_response :not_found
    end

    def test_show_auto_fills_missing_variable
      get "/auto_preview/show", params: {template: "pages/greeting.html.erb"}

      assert_response :success
      # Should auto-generate a value and render the template
      assert_preview_includes "Hello,"
      # Edit overlay should show the variable for modification
      assert_includes response.body, "name"
      assert_includes response.body, "vars[name][type]"
      assert_includes response.body, "vars[name][value]"
    end

    def test_show_renders_template_with_string_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "String", value: "Alice"}}
      }

      assert_response :success
      assert_preview_includes "Hello, Alice!"
    end

    def test_show_renders_template_with_integer_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Integer", value: "42"}}
      }

      assert_response :success
      assert_preview_includes "Hello, 42!"
    end

    def test_show_renders_template_with_float_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Float", value: "3.14"}}
      }

      assert_response :success
      assert_preview_includes "Hello, 3.14!"
    end

    def test_show_renders_template_with_boolean_true_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Boolean", value: "true"}}
      }

      assert_response :success
      assert_preview_includes "Hello, true!"
    end

    def test_show_renders_template_with_boolean_false_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Boolean", value: "false"}}
      }

      assert_response :success
      assert_preview_includes "Hello, false!"
    end

    def test_show_renders_template_with_nil_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "NilClass", value: ""}}
      }

      assert_response :success
      assert_preview_includes "Hello, !"
    end

    def test_show_renders_template_with_array_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Array", value: '["a", "b", "c"]'}}
      }

      assert_response :success
      # HTML-escapes quotes in the output
      assert_preview_includes "Hello, ["
      assert_preview_includes "a"
    end

    def test_show_renders_template_with_hash_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Hash", value: '{"key": "value"}'}}
      }

      assert_response :success
      # HTML-escapes quotes in the output
      assert_preview_includes "Hello, {"
      assert_preview_includes "key"
    end

    def test_show_preserves_existing_vars_in_form
      # First request triggers the form
      get "/auto_preview/show", params: {
        template: "pages/multi_var.html.erb",
        vars: {first_var: {type: "String", value: "hello"}}
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
          first_var: {type: "String", value: "hello"},
          second_var: {type: "String", value: "world"}
        }
      }

      assert_response :success
      assert_preview_includes "First: hello"
      assert_preview_includes "Second: world"
    end

    def test_show_handles_empty_vars_param
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {}
      }

      assert_response :success
      # Should auto-generate values and render successfully
      assert_preview_includes "Hello,"
    end

    def test_show_handles_invalid_vars_format
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: "invalid"
      }

      assert_response :success
      # Should auto-generate values and render successfully even with invalid vars format
      assert_preview_includes "Hello,"
    end

    def test_show_raises_non_name_error_template_errors
      get "/auto_preview/show", params: {template: "pages/error_test.html.erb"}

      # Non-NameError template errors should propagate and result in server error
      assert_response :internal_server_error
    end

    def test_show_raises_name_error_with_unmatched_message_format
      # This template causes a NameError with a message that doesn't match
      # the "undefined local variable or method" pattern (e.g., uninitialized constant)
      get "/auto_preview/show", params: {template: "pages/unmatched_error.html.erb"}

      # Should re-raise the error since we can't extract the variable name
      assert_response :internal_server_error
    end

    def test_show_auto_fills_locals_detected_via_scanning
      # The _user_profile partial is rendered with user_name and user_email in dashboard.html.erb
      # The scanner should detect these and auto-fill values to render
      get "/auto_preview/show", params: {template: "pages/_user_profile.html.erb"}

      assert_response :success
      # Should auto-generate values and render successfully
      assert_preview_includes "User Profile"
      # Edit overlay should show the auto-filled variables
      assert(response.body.include?("user_name") || response.body.include?("user_email"))
    end

    def test_show_renders_partial_with_scanned_locals_provided
      get "/auto_preview/show", params: {
        template: "pages/_user_profile.html.erb",
        vars: {
          user_name: {type: "String", value: "John Doe"},
          user_email: {type: "String", value: "john@example.com"}
        }
      }

      assert_response :success
      assert_preview_includes "John Doe"
      assert_preview_includes "john@example.com"
    end

    def test_show_auto_fills_remaining_locals_when_some_already_provided
      # Provide only user_name but not user_email
      # This should auto-fill user_email and render the template
      get "/auto_preview/show", params: {
        template: "pages/_user_profile.html.erb",
        vars: {
          user_name: {type: "String", value: "Jane Doe"}
        }
      }

      assert_response :success
      # Should auto-generate missing value and render successfully
      assert_preview_includes "User Profile"
      # The provided var should be used
      assert_preview_includes "Jane Doe"
      # The edit overlay should show both variables
      assert_includes response.body, "user_email"
    end

    def test_show_renders_with_controller_without_helpers
      # Test rendering with a controller that doesn't respond to _helpers
      # This covers the else branch of `if controller_class.respond_to?(:_helpers)`
      get "/auto_preview/show", params: {
        template: "pages/home.html.erb",
        controller_context: "MinimalController"
      }

      assert_response :success
      assert_preview_includes "Home Page"
    end

    def test_show_renders_with_minimal_controller_and_predicate_methods
      # Test rendering with MinimalController (which doesn't respond to :render)
      # and predicate methods - covers the fallback path with define_singleton_method
      get "/auto_preview/show", params: {
        template: "pages/conditional_feature.html.erb",
        controller_context: "MinimalController",
        vars: {
          "premium_user?": {type: "Boolean", value: "true"},
          "user_name": {type: "String", value: "Test User"}
        }
      }

      assert_response :success
      assert_preview_includes "Premium User"
      assert_preview_includes "Test User"
    end

    def test_show_renders_with_controller_layout
      # Test that the layout from the controller context is rendered
      get "/auto_preview/show", params: {
        template: "pages/home.html.erb",
        controller_context: "PagesController"
      }

      assert_response :success
      assert_preview_includes "<html><body>"
      assert_preview_includes "</body></html>"
      assert_preview_includes "Home Page"
    end

    def test_show_renders_template_with_factory_variable
      initial_count = User.count

      get "/auto_preview/show", params: {
        template: "pages/user_card.html.erb",
        vars: {user: {type: "Factory", value: "user"}}
      }

      assert_response :success
      assert_preview_includes "John Doe"
      assert_preview_includes "john@example.com"
      # Factory should be rolled back - no new records persisted
      assert_equal initial_count, User.count
    end

    def test_show_renders_template_with_factory_trait
      initial_count = User.count

      get "/auto_preview/show", params: {
        template: "pages/user_card.html.erb",
        vars: {user: {type: "Factory", value: "user:admin"}}
      }

      assert_response :success
      assert_preview_includes "Admin User"
      assert_preview_includes "admin@example.com"
      # Factory should be rolled back - no new records persisted
      assert_equal initial_count, User.count
    end

    def test_show_auto_fills_variable_with_factory
      initial_count = User.count

      get "/auto_preview/show", params: {template: "pages/user_card.html.erb"}

      assert_response :success
      # Should auto-detect user factory and render with factory-created user
      assert_preview_includes "John Doe"
      assert_preview_includes "john@example.com"
      # Factory should be rolled back - no new records persisted
      assert_equal initial_count, User.count
      # Edit overlay should show Factory type selected
      assert_includes response.body, "Factory"
    end

    # Predicate helper method tests
    def test_show_auto_fills_missing_variables_in_conditional_feature
      # Template should auto-fill missing variables and render
      get "/auto_preview/show", params: {template: "pages/conditional_feature.html.erb"}

      assert_response :success
      # Should render the conditional feature page
      assert_preview_includes "Conditional Feature Demo"
      # Edit overlay should show the auto-filled variables
      assert(response.body.include?("premium_user?") || response.body.include?("user_name"))
    end

    def test_show_predicate_defaults_to_boolean_type
      # When prompting for a predicate method, Boolean should be preselected
      # Request without providing premium_user? - it should be auto-filled
      get "/auto_preview/show", params: {
        template: "pages/conditional_feature.html.erb"
      }

      assert_response :success
      # If premium_user? is shown in the sidebar form (not just in source code),
      # Boolean should be preselected
      # Check for the form field with premium_user? label
      if response.body.include?('vars[premium_user?][type]')
        # Check for selected attribute in the HTML (various formats: selected, selected="selected", etc.)
        boolean_option_pattern = /<option[^>]*value="Boolean"[^>]*selected[^>]*>/
        assert_match boolean_option_pattern, response.body, "Expected Boolean to be selected for predicate variable"
      else
        # It auto-filled the variable and rendered successfully without prompting
        assert_preview_includes "Conditional Feature Demo"
      end
    end

    def test_show_renders_predicate_helper_true
      get "/auto_preview/show", params: {
        template: "pages/conditional_feature.html.erb",
        vars: {
          "premium_user?": {type: "Boolean", value: "true"},
          user_name: {type: "String", value: "Alice"}
        }
      }

      assert_response :success
      assert_preview_includes "Premium User"
      assert_preview_includes "Advanced analytics"
      assert_preview_includes "Your name: Alice"
    end

    def test_show_renders_predicate_helper_false
      get "/auto_preview/show", params: {
        template: "pages/conditional_feature.html.erb",
        vars: {
          "premium_user?": {type: "Boolean", value: "false"},
          user_name: {type: "String", value: "Bob"}
        }
      }

      assert_response :success
      assert_preview_includes "Basic User"
      assert_preview_includes "Upgrade to premium"
      assert_preview_includes "Your name: Bob"
      # Note: "Advanced analytics" is in the template source but not in the rendered preview
      # We can only check the iframe srcdoc doesn't contain it (not the whole response which has template source)
      # Extract the srcdoc content to verify
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])
      refute_includes srcdoc_content, "Advanced analytics", "Expected rendered preview not to include 'Advanced analytics'"
    end

    def test_show_includes_sidebar_and_preview_iframe
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "String", value: "World"}}
      }

      assert_response :success
      assert_preview_includes "Hello, World!"
      # Sidebar layout elements
      assert_includes response.body, "auto-preview-sidebar"
      assert_includes response.body, "auto-preview-layout"
      assert_includes response.body, "previewFrame"
      # Tab controls
      assert_includes response.body, "Preview"
      assert_includes response.body, "Source"
    end

    def test_show_sidebar_includes_existing_variables
      get "/auto_preview/show", params: {
        template: "pages/multi_var.html.erb",
        vars: {
          first_var: {type: "String", value: "hello"},
          second_var: {type: "Integer", value: "42"}
        }
      }

      assert_response :success
      # Sidebar should show existing vars for editing
      assert_includes response.body, "first_var"
      assert_includes response.body, "second_var"
      assert_includes response.body, "hello"
      assert_includes response.body, "42"
    end

    def test_show_catches_no_method_error_for_predicate
      # NoMethodError should be caught and variable should be auto-filled
      get "/auto_preview/show", params: {template: "pages/conditional_feature.html.erb"}

      assert_response :success
      # Should auto-fill values and render successfully (not crash)
      assert_preview_includes "Conditional Feature Demo"
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

    def test_find_controllers_skips_nonexistent_paths
      controller = PreviewsController.new

      controller.stub(:controller_paths, ["/nonexistent/path"]) do
        result = controller.send(:find_controllers)
        assert_equal ["ActionController::Base"], result
      end
    end

    def test_add_scanned_instance_variables_returns_vars_with_instance_variables
      controller = PreviewsController.new
      template_source = '<%= @current_user.name %>'
      vars = {}

      result = controller.send(:add_scanned_instance_variables, template_source, vars)

      assert result.key?("@current_user")
      assert_equal "Factory", result["@current_user"]["type"]
      assert_equal "user", result["@current_user"]["value"]
    end

    def test_add_scanned_instance_variables_skips_internal_rails_ivars
      controller = PreviewsController.new
      template_source = '<%= @_output_buffer %>'
      vars = {}

      result = controller.send(:add_scanned_instance_variables, template_source, vars)

      refute result.key?("@_output_buffer")
    end

    def test_add_scanned_instance_variables_skips_existing_vars
      controller = PreviewsController.new
      template_source = '<%= @user.name %>'
      vars = {"@user" => {"type" => "String", "value" => "existing"}}

      result = controller.send(:add_scanned_instance_variables, template_source, vars)

      assert_equal "existing", result["@user"]["value"]
    end

    def test_add_scanned_instance_variables_with_action_controller_parameters
      controller = PreviewsController.new
      template_source = '<%= @user.name %>'
      vars = ActionController::Parameters.new({})

      result = controller.send(:add_scanned_instance_variables, template_source, vars)

      assert result.key?("@user")
    end

    def test_build_assigns_creates_assigns_from_instance_variables
      controller = PreviewsController.new
      vars = {"@current_user" => {"type" => "Factory", "value" => "user"}}

      result = controller.send(:build_assigns, vars)

      assert result.key?("current_user")
      assert_instance_of User, result["current_user"]
    end

    def test_build_assigns_skips_non_instance_variables
      controller = PreviewsController.new
      vars = {"name" => {"type" => "String", "value" => "test"}}

      result = controller.send(:build_assigns, vars)

      refute result.key?("name")
      refute result.key?("@name")
    end

    def test_build_assigns_handles_action_controller_parameters
      controller = PreviewsController.new
      vars = ActionController::Parameters.new({"@user" => {"type" => "String", "value" => "test"}})

      result = controller.send(:build_assigns, vars)

      assert result.key?("user")
      assert_equal "test", result["user"]
    end

    def test_build_assigns_returns_empty_hash_for_invalid_vars
      controller = PreviewsController.new

      result = controller.send(:build_assigns, "invalid")

      assert_equal({}, result)
    end

    def test_build_assigns_skips_non_hash_config
      controller = PreviewsController.new
      vars = {"@user" => "not a hash"}

      result = controller.send(:build_assigns, vars)

      refute result.key?("user")
    end

    def test_build_assigns_with_symbol_keys
      controller = PreviewsController.new
      vars = {"@user" => {type: "String", value: "test"}}

      result = controller.send(:build_assigns, vars)

      assert_equal "test", result["user"]
    end

    def test_build_assigns_with_plain_hash_config
      # Test with a plain hash that doesn't respond to to_unsafe_h
      controller = PreviewsController.new
      config = {"type" => "String", "value" => "plain_hash_value"}
      refute config.respond_to?(:to_unsafe_h), "Expected plain hash not to respond to to_unsafe_h"

      vars = {"@plain" => config}
      result = controller.send(:build_assigns, vars)

      assert_equal "plain_hash_value", result["plain"]
    end

    def test_view_component_template_returns_true_when_rb_file_exists
      controller = PreviewsController.new
      temp_dir = Dir.mktmpdir

      # Create a ViewComponent-style template with co-located .rb file
      erb_file = File.join(temp_dir, "my_component.html.erb")
      rb_file = File.join(temp_dir, "my_component.rb")
      File.write(erb_file, "<div>Component</div>")
      File.write(rb_file, "class MyComponent; end")

      result = controller.send(:view_component_template?, erb_file)
      assert result, "Should detect ViewComponent template when .rb file exists"
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir
    end

    def test_view_component_template_returns_false_when_no_rb_file
      controller = PreviewsController.new
      temp_dir = Dir.mktmpdir

      # Create a regular ERB file without co-located .rb file
      erb_file = File.join(temp_dir, "regular_template.html.erb")
      File.write(erb_file, "<div>Template</div>")

      result = controller.send(:view_component_template?, erb_file)
      refute result, "Should not detect ViewComponent template when .rb file does not exist"
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir
    end

    def test_find_erb_files_excludes_view_component_templates
      controller = PreviewsController.new
      temp_dir = Dir.mktmpdir

      # Simulate Rails root with a ViewComponent template
      component_erb = File.join(temp_dir, "app", "components", "card_component.html.erb")
      component_rb = File.join(temp_dir, "app", "components", "card_component.rb")
      FileUtils.mkdir_p(File.dirname(component_erb))
      File.write(component_erb, "<div>Card</div>")
      File.write(component_rb, "class CardComponent; end")

      # Create a regular template that should be included
      regular_erb = File.join(temp_dir, "app", "custom", "page.html.erb")
      FileUtils.mkdir_p(File.dirname(regular_erb))
      File.write(regular_erb, "<div>Page</div>")

      # Stub Rails.root and view_paths
      mock_rails_root = Pathname.new(temp_dir)

      controller.stub(:view_paths, []) do
        ::Rails.stub(:root, mock_rails_root) do
          result = controller.send(:find_erb_files)

          refute result.include?("app/components/card_component.html.erb"),
            "Should exclude ViewComponent templates"
          assert result.include?("app/custom/page.html.erb"),
            "Should include regular templates"
        end
      end
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir
    end
  end
end
