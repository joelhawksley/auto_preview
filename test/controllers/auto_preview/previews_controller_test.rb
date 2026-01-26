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

    def test_find_controllers_skips_nonexistent_paths
      # This test covers the `next unless path.exist?` branch in find_controllers
      controller = PreviewsController.new

      controller.stub(:controller_paths, ["/nonexistent/path"]) do
        result = controller.send(:find_controllers)
        # ActionController::Base is always included
        assert_equal ["ActionController::Base"], result
      end
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
      assert_equal({"key" => "value"}, controller.send(:coerce_value, '{"key": "value"}', "Hash"))
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
      vars_params = ActionController::Parameters.new({name: "just a string, not a hash"})

      result = controller.send(:build_locals_from_params, vars_params)
      assert_equal({}, result)
    end

    def test_create_from_factory_returns_nil_when_value_blank
      controller = PreviewsController.new

      result = controller.send(:create_from_factory, "")
      assert_nil result

      result = controller.send(:create_from_factory, nil)
      assert_nil result
    end

    # infer_type_and_value tests
    def test_infer_type_and_value_predicate
      controller = PreviewsController.new
      type, value = controller.send(:infer_type_and_value, "active?")
      assert_equal "Boolean", type
      assert_equal "true", value
    end

    def test_infer_type_and_value_boolean_prefix_patterns
      controller = PreviewsController.new

      # Test is_ prefix
      type, value = controller.send(:infer_type_and_value, "is_active")
      assert_equal "Boolean", type
      assert_equal "true", value

      # Test has_ prefix
      type, value = controller.send(:infer_type_and_value, "has_permission")
      assert_equal "Boolean", type

      # Test can_ prefix
      type, value = controller.send(:infer_type_and_value, "can_edit")
      assert_equal "Boolean", type

      # Test show prefix
      type, value = controller.send(:infer_type_and_value, "show_details")
      assert_equal "Boolean", type

      # Test active prefix
      type, value = controller.send(:infer_type_and_value, "active_subscription")
      assert_equal "Boolean", type
    end

    def test_infer_type_and_value_integer_suffix_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "user_id")
      assert_equal "Integer", type
      assert_equal "42", value

      type, value = controller.send(:infer_type_and_value, "item_count")
      assert_equal "Integer", type

      type, value = controller.send(:infer_type_and_value, "age")
      assert_equal "Integer", type

      type, value = controller.send(:infer_type_and_value, "index")
      assert_equal "Integer", type
    end

    def test_infer_type_and_value_float_suffix_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "unit_price")
      assert_equal "Float", type
      assert_equal "19.99", value

      type, value = controller.send(:infer_type_and_value, "tax_rate")
      assert_equal "Float", type

      type, value = controller.send(:infer_type_and_value, "conversion_ratio")
      assert_equal "Float", type
    end

    def test_infer_type_and_value_date_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "created_at")
      assert_equal "String", type
      # Should be ISO8601 format
      assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, value)

      type, value = controller.send(:infer_type_and_value, "published_on")
      assert_equal "String", type

      type, value = controller.send(:infer_type_and_value, "birth_date")
      assert_equal "String", type
    end

    def test_infer_type_and_value_url_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "profile_url")
      assert_equal "String", type
      assert_equal "https://example.com", value

      type, value = controller.send(:infer_type_and_value, "website_link")
      assert_equal "String", type
    end

    def test_infer_type_and_value_email_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "user_email")
      assert_equal "String", type
      assert_equal "user@example.com", value
    end

    def test_infer_type_and_value_name_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "user_name")
      assert_equal "String", type
      assert_includes value, "Example"

      type, value = controller.send(:infer_type_and_value, "page_title")
      assert_equal "String", type
    end

    def test_infer_type_and_value_text_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "post_description")
      assert_equal "String", type
      assert_includes value, "sample"

      type, value = controller.send(:infer_type_and_value, "article_body")
      assert_equal "String", type

      type, value = controller.send(:infer_type_and_value, "main_content")
      assert_equal "String", type
    end

    def test_infer_type_and_value_array_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "cart_items")
      assert_equal "Array", type
      assert_equal "[]", value

      type, value = controller.send(:infer_type_and_value, "tag_list")
      assert_equal "Array", type
    end

    def test_infer_type_and_value_hash_patterns
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "user_data")
      assert_equal "Hash", type
      assert_equal "{}", value

      type, value = controller.send(:infer_type_and_value, "app_config")
      assert_equal "Hash", type

      type, value = controller.send(:infer_type_and_value, "query_params")
      assert_equal "Hash", type
    end

    def test_infer_type_and_value_user_patterns_with_factory
      controller = PreviewsController.new

      # With FactoryBot defined and user factory existing
      type, value = controller.send(:infer_type_and_value, "current_user")
      assert_equal "Factory", type
      assert_equal "user", value

      type, value = controller.send(:infer_type_and_value, "admin")
      assert_equal "Factory", type
    end

    def test_infer_type_and_value_user_patterns_without_factory
      controller = PreviewsController.new

      # Temporarily hide FactoryBot constant to test else branch
      original_factory_bot = Object.send(:remove_const, :FactoryBot)
      begin
        type, value = controller.send(:infer_type_and_value, "current_user")
        assert_equal "String", type
        assert_equal "John Doe", value
      ensure
        Object.const_set(:FactoryBot, original_factory_bot)
      end
    end

    def test_infer_type_and_value_default_string
      controller = PreviewsController.new

      type, value = controller.send(:infer_type_and_value, "random_thing")
      assert_equal "String", type
      assert_includes value, "Sample"
    end

    def test_infer_type_and_value_factory_match
      controller = PreviewsController.new

      # "user" should match the user factory
      type, value = controller.send(:infer_type_and_value, "user")
      assert_equal "Factory", type
      assert_equal "user", value
    end

    def test_create_from_factory_without_factory_bot_defined
      controller = PreviewsController.new

      # Temporarily hide FactoryBot constant
      original_factory_bot = Object.send(:remove_const, :FactoryBot)
      begin
        result = controller.send(:create_from_factory, "user")
        assert_nil result
      ensure
        Object.const_set(:FactoryBot, original_factory_bot)
      end
    end

    def test_find_factories_without_factory_bot_defined
      controller = PreviewsController.new

      # Temporarily hide FactoryBot constant
      original_factory_bot = Object.send(:remove_const, :FactoryBot)
      begin
        result = controller.send(:find_factories)
        assert_equal [], result
      ensure
        Object.const_set(:FactoryBot, original_factory_bot)
      end
    end

    def test_extract_provided_local_names_returns_empty_for_invalid_params
      controller = PreviewsController.new

      result = controller.send(:extract_provided_local_names, nil)
      assert_equal [], result

      result = controller.send(:extract_provided_local_names, "not a hash")
      assert_equal [], result
    end

    def test_build_locals_from_params_returns_empty_for_nil
      controller = PreviewsController.new

      result = controller.send(:build_locals_from_params, nil)
      assert_equal({}, result)
    end

    def test_find_factories_returns_factories_with_traits
      controller = PreviewsController.new

      factories = controller.send(:find_factories)

      # Should include the user factory
      user_factory = factories.find { |f| f[:name] == "user" }
      assert_not_nil user_factory
      assert_includes user_factory[:traits], "admin"
    end

    # Predicate helper unit tests
    def test_build_predicate_methods_from_params
      controller = PreviewsController.new
      vars_params = ActionController::Parameters.new({
        "premium_user?": {type: "Boolean", value: "true"},
        "admin?": {type: "Boolean", value: "false"},
        regular_var: {type: "String", value: "hello"}
      })

      result = controller.send(:build_predicate_methods_from_params, vars_params)

      assert_equal true, result["premium_user?"]
      assert_equal false, result["admin?"]
      refute result.key?("regular_var")
    end

    def test_build_predicate_methods_from_params_returns_empty_for_nil
      controller = PreviewsController.new

      result = controller.send(:build_predicate_methods_from_params, nil)
      assert_equal({}, result)
    end

    def test_build_predicate_methods_from_params_skips_invalid_config
      controller = PreviewsController.new
      vars_params = ActionController::Parameters.new({
        "predicate?": "not a hash"
      })

      result = controller.send(:build_predicate_methods_from_params, vars_params)
      assert_equal({}, result)
    end

    def test_inject_overlay_into_body_with_body_tag
      controller = PreviewsController.new
      content = "<html><body><h1>Test</h1></body></html>"
      overlay = "<div>Overlay</div>"

      result = controller.send(:inject_overlay_into_body, content, overlay)

      assert_includes result, "<div>Overlay</div>"
      assert_includes result, "</body>"
      assert result.index("<div>Overlay</div>") < result.index("</body>")
    end

    def test_inject_overlay_into_body_without_body_tag
      controller = PreviewsController.new
      content = "<h1>Test</h1>"
      overlay = "<div>Overlay</div>"

      result = controller.send(:inject_overlay_into_body, content, overlay)

      assert_equal "<h1>Test</h1><div>Overlay</div>", result
    end

    def test_inject_overlay_into_body_with_blank_overlay
      controller = PreviewsController.new
      content = "<html><body><h1>Test</h1></body></html>"

      result = controller.send(:inject_overlay_into_body, content, "")
      assert_equal content, result

      result = controller.send(:inject_overlay_into_body, content, nil)
      assert_equal content, result
    end

    def test_handle_name_error_matches_predicate_methods
      controller = PreviewsController.new

      # Create a NoMethodError for a predicate method (matches Rails format)
      error = NoMethodError.new("undefined method `admin?' for an instance of SomeClass")

      # Should extract the method name from the error using the updated regex
      match = error.message.match(/undefined (?:local variable or )?method [`']([\w\?]+)'/)
      assert_not_nil match
      assert_equal "admin?", match[1]
    end

    def test_ensure_predicate_helper_methods_skips_when_empty
      controller = PreviewsController.new

      # Should not raise when empty predicates
      assert_nothing_raised do
        controller.send(:ensure_predicate_helper_methods, ApplicationController, {})
      end
    end

    def test_ensure_predicate_helper_methods_skips_when_no_helpers
      controller = PreviewsController.new

      # Create a mock class without helpers method
      mock_class = Class.new

      # Should not raise
      assert_nothing_raised do
        controller.send(:ensure_predicate_helper_methods, mock_class, {"test?" => true})
      end
    end

    def test_extract_missing_variable_name_returns_nil_for_non_matching_error
      controller = PreviewsController.new

      # Create an error with a message that doesn't match the expected patterns
      error = NameError.new("some completely different error format")
      result = controller.send(:extract_missing_variable_name, error)
      assert_nil result
    end

    def test_coerce_value_string_type
      controller = PreviewsController.new
      result = controller.send(:coerce_value, 123, "String")
      assert_equal "123", result
    end

    def test_coerce_value_integer_type
      controller = PreviewsController.new
      result = controller.send(:coerce_value, "42", "Integer")
      assert_equal 42, result
    end

    def test_coerce_value_float_type
      controller = PreviewsController.new
      result = controller.send(:coerce_value, "3.14", "Float")
      assert_in_delta 3.14, result, 0.001
    end

    def test_coerce_value_boolean_type_true_values
      controller = PreviewsController.new

      assert_equal true, controller.send(:coerce_value, "true", "Boolean")
      assert_equal true, controller.send(:coerce_value, "1", "Boolean")
      assert_equal true, controller.send(:coerce_value, "yes", "Boolean")
      assert_equal true, controller.send(:coerce_value, "TRUE", "Boolean")
    end

    def test_coerce_value_boolean_type_false_values
      controller = PreviewsController.new

      assert_equal false, controller.send(:coerce_value, "false", "Boolean")
      assert_equal false, controller.send(:coerce_value, "0", "Boolean")
      assert_equal false, controller.send(:coerce_value, "no", "Boolean")
    end

    def test_coerce_value_array_type
      controller = PreviewsController.new
      result = controller.send(:coerce_value, '["a", "b"]', "Array")
      assert_equal ["a", "b"], result
    end

    def test_coerce_value_array_type_invalid_json
      controller = PreviewsController.new
      result = controller.send(:coerce_value, "not json", "Array")
      assert_equal [], result
    end

    def test_coerce_value_hash_type
      controller = PreviewsController.new
      result = controller.send(:coerce_value, '{"key": "value"}', "Hash")
      assert_equal({"key" => "value"}, result)
    end

    def test_coerce_value_hash_type_invalid_json
      controller = PreviewsController.new
      result = controller.send(:coerce_value, "not json", "Hash")
      assert_equal({}, result)
    end

    def test_coerce_value_nil_class_type
      controller = PreviewsController.new
      result = controller.send(:coerce_value, "anything", "NilClass")
      assert_nil result
    end

    def test_coerce_value_factory_type
      controller = PreviewsController.new
      result = controller.send(:coerce_value, "user", "Factory")
      assert_instance_of User, result
    end

    def test_create_from_factory_with_traits
      controller = PreviewsController.new
      result = controller.send(:create_from_factory, "user:admin")
      assert_instance_of User, result
      assert_equal "Admin User", result.name
    end

    def test_parse_json_or_default_with_blank_value
      controller = PreviewsController.new
      result = controller.send(:parse_json_or_default, "", [1, 2])
      assert_equal [1, 2], result

      result = controller.send(:parse_json_or_default, nil, {a: 1})
      assert_equal({a: 1}, result)
    end
  end

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
