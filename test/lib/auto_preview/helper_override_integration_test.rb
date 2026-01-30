# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class HelperOverrideIntegrationTest < ActionDispatch::IntegrationTest
    def setup
      @original_helper_methods = AutoPreview.helper_methods
    end

    def teardown
      AutoPreview.helper_methods = @original_helper_methods
    end

    def test_helper_override_with_factory_returns_user_object_in_template
      AutoPreview.helper_methods = {current_user: :user}

      get "/auto_preview/show", params: {
        template: "pages/current_user_test.html.erb",
        vars: {
          current_user: {type: "Factory", value: "user"}
        }
      }

      assert_response :success
      # Extract the iframe srcdoc content - the preview is rendered inside
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])

      # The current_user helper should return a User object, not nil
      # The template should display the user's name
      assert_includes srcdoc_content, "John Doe"
      refute_includes srcdoc_content, "No current user"
    end

    def test_helper_override_auto_fills_when_no_var_provided
      # When user configures a helper but doesn't provide a var value,
      # the system should auto-fill it with the default factory value
      AutoPreview.helper_methods = {current_user: :user}

      get "/auto_preview/show", params: {
        template: "pages/current_user_test.html.erb"
        # Note: NOT providing current_user in vars
      }

      assert_response :success
      # Extract the iframe srcdoc content - the preview is rendered inside
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])

      # The current_user helper should be auto-filled with the factory
      # and return a User object, not nil
      assert_includes srcdoc_content, "John Doe"
      refute_includes srcdoc_content, "No current user"
    end

    def test_helper_override_with_pages_controller_context
      # Test with a specific controller context that has a layout
      AutoPreview.helper_methods = {current_user: :user}

      get "/auto_preview/show", params: {
        template: "pages/current_user_test.html.erb",
        controller_context: "PagesController",
        vars: {
          current_user: {type: "Factory", value: "user"}
        }
      }

      assert_response :success
      # Extract the iframe srcdoc content - the preview is rendered inside
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])

      # The current_user helper should return a User object, not nil
      assert_includes srcdoc_content, "John Doe"
      refute_includes srcdoc_content, "No current user"
    end

    def test_helper_override_with_action_controller_base_context
      # Test with ActionController::Base as the controller context
      AutoPreview.helper_methods = {current_user: :user}

      get "/auto_preview/show", params: {
        template: "pages/current_user_test.html.erb",
        controller_context: "ActionController::Base",
        vars: {
          current_user: {type: "Factory", value: "user"}
        }
      }

      assert_response :success
      # Extract the iframe srcdoc content - the preview is rendered inside
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])

      # The current_user helper should return a User object, not nil
      assert_includes srcdoc_content, "John Doe"
      refute_includes srcdoc_content, "No current user"
    end

    def test_helper_override_with_minimal_controller_context
      # Test with MinimalController which doesn't respond to :render
      # This tests the fallback code path
      AutoPreview.helper_methods = {current_user: :user}

      get "/auto_preview/show", params: {
        template: "pages/current_user_test.html.erb",
        controller_context: "MinimalController",
        vars: {
          current_user: {type: "Factory", value: "user"}
        }
      }

      assert_response :success
      # Extract the iframe srcdoc content - the preview is rendered inside
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])

      # The current_user helper should return a User object, not nil
      assert_includes srcdoc_content, "John Doe"
      refute_includes srcdoc_content, "No current user"
    end

    def test_helper_override_with_proc_executes_proc
      # When a Proc is configured, it should be executed at render time
      AutoPreview.helper_methods = {current_user: -> { FactoryBot.create(:user, name: "Proc User") }}

      get "/auto_preview/show", params: {
        template: "pages/current_user_test.html.erb",
        vars: {
          current_user: {type: "Proc", value: ""}
        }
      }

      assert_response :success
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])

      # The proc should have been executed, creating a user with the custom name
      assert_includes srcdoc_content, "Proc User"
      refute_includes srcdoc_content, "No current user"
    end

    def test_helper_override_with_proc_auto_fills
      # When a Proc is configured and no var is provided, it should auto-fill and execute
      AutoPreview.helper_methods = {current_user: -> { FactoryBot.create(:user, name: "Auto Proc User") }}

      get "/auto_preview/show", params: {
        template: "pages/current_user_test.html.erb"
        # Note: NOT providing current_user in vars
      }

      assert_response :success
      srcdoc_match = response.body.match(/srcdoc="([^"]*)"/)
      assert srcdoc_match, "Expected to find srcdoc attribute"
      srcdoc_content = CGI.unescapeHTML(srcdoc_match[1])

      # The proc should have been executed
      assert_includes srcdoc_content, "Auto Proc User"
      refute_includes srcdoc_content, "No current user"
    end
  end
end
