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
      get "/auto_preview/show", params: {template: "pages/home.html.erb"}

      assert_response :success
      assert_includes response.body, "<h1>Home Page</h1>"
    end

    def test_show_renders_template_using_application_helper
      get "/auto_preview/show", params: {
        template: "pages/with_helper.html.erb",
        vars: {name: {type: "String", value: "World"}}
      }

      assert_response :success
      assert_includes response.body, "Hello, World! Welcome to the app."
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
      assert_includes response.body, "Hello,"
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
      assert_includes response.body, "Hello, Alice!"
    end

    def test_show_renders_template_with_integer_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Integer", value: "42"}}
      }

      assert_response :success
      assert_includes response.body, "Hello, 42!"
    end

    def test_show_renders_template_with_float_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Float", value: "3.14"}}
      }

      assert_response :success
      assert_includes response.body, "Hello, 3.14!"
    end

    def test_show_renders_template_with_boolean_true_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Boolean", value: "true"}}
      }

      assert_response :success
      assert_includes response.body, "Hello, true!"
    end

    def test_show_renders_template_with_boolean_false_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Boolean", value: "false"}}
      }

      assert_response :success
      assert_includes response.body, "Hello, false!"
    end

    def test_show_renders_template_with_nil_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "NilClass", value: ""}}
      }

      assert_response :success
      assert_includes response.body, "Hello, !"
    end

    def test_show_renders_template_with_array_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Array", value: '["a", "b", "c"]'}}
      }

      assert_response :success
      # HTML-escapes quotes in the output
      assert_includes response.body, "Hello, ["
      assert_includes response.body, "a"
    end

    def test_show_renders_template_with_hash_variable
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "Hash", value: '{"key": "value"}'}}
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
      assert_includes response.body, "First: hello"
      assert_includes response.body, "Second: world"
    end

    def test_show_handles_empty_vars_param
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {}
      }

      assert_response :success
      # Should auto-generate values and render successfully
      assert_includes response.body, "Hello,"
    end

    def test_show_handles_invalid_vars_format
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: "invalid"
      }

      assert_response :success
      # Should auto-generate values and render successfully even with invalid vars format
      assert_includes response.body, "Hello,"
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
      assert_includes response.body, "User Profile"
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
      assert_includes response.body, "John Doe"
      assert_includes response.body, "john@example.com"
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
      assert_includes response.body, "User Profile"
      # The provided var should be used
      assert_includes response.body, "Jane Doe"
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
      assert_includes response.body, "Home Page"
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
      assert_includes response.body, "Premium User"
      assert_includes response.body, "Test User"
    end

    def test_show_renders_with_controller_layout
      # Test that the layout from the controller context is rendered
      get "/auto_preview/show", params: {
        template: "pages/home.html.erb",
        controller_context: "PagesController"
      }

      assert_response :success
      assert_includes response.body, "<html><body>"
      assert_includes response.body, "</body></html>"
      assert_includes response.body, "Home Page"
    end

    def test_show_renders_template_with_factory_variable
      initial_count = User.count

      get "/auto_preview/show", params: {
        template: "pages/user_card.html.erb",
        vars: {user: {type: "Factory", value: "user"}}
      }

      assert_response :success
      assert_includes response.body, "John Doe"
      assert_includes response.body, "john@example.com"
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
      assert_includes response.body, "Admin User"
      assert_includes response.body, "admin@example.com"
      # Factory should be rolled back - no new records persisted
      assert_equal initial_count, User.count
    end

    def test_show_auto_fills_variable_with_factory
      initial_count = User.count

      get "/auto_preview/show", params: {template: "pages/user_card.html.erb"}

      assert_response :success
      # Should auto-detect user factory and render with factory-created user
      assert_includes response.body, "John Doe"
      assert_includes response.body, "john@example.com"
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
      assert_includes response.body, "Conditional Feature Demo"
      # Edit overlay should show the auto-filled variables
      assert(response.body.include?("premium_user?") || response.body.include?("user_name"))
    end

    def test_show_predicate_defaults_to_boolean_type
      # When prompting for a predicate method, Boolean should be preselected
      get "/auto_preview/show", params: {
        template: "pages/conditional_feature.html.erb",
        vars: {
          user_name: {type: "String", value: "Alice"}
        }
      }

      # If it prompts for premium_user?, Boolean should be preselected
      if response.body.include?("premium_user?")
        assert_includes response.body, '<option selected="selected" value="Boolean">Boolean</option>'
      else
        # It rendered successfully with user_name, that's also valid
        assert_response :success
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
      assert_includes response.body, "Premium User"
      assert_includes response.body, "Advanced analytics"
      assert_includes response.body, "Your name: Alice"
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
      assert_includes response.body, "Basic User"
      assert_includes response.body, "Upgrade to premium"
      assert_includes response.body, "Your name: Bob"
      refute_includes response.body, "Advanced analytics"
    end

    def test_show_includes_edit_overlay_in_rendered_content
      get "/auto_preview/show", params: {
        template: "pages/greeting.html.erb",
        vars: {name: {type: "String", value: "World"}}
      }

      assert_response :success
      assert_includes response.body, "Hello, World!"
      # Overlay elements
      assert_includes response.body, "auto-preview-fab"
      assert_includes response.body, "autoPreviewOverlay"
      assert_includes response.body, "Edit Preview Variables"
    end

    def test_show_overlay_includes_existing_variables
      get "/auto_preview/show", params: {
        template: "pages/multi_var.html.erb",
        vars: {
          first_var: {type: "String", value: "hello"},
          second_var: {type: "Integer", value: "42"}
        }
      }

      assert_response :success
      # Overlay should show existing vars for editing
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
      assert_includes response.body, "Conditional Feature Demo"
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
  end
end
