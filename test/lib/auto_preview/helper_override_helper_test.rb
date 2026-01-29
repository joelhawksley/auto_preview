# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class HelperOverrideHelperTest < ActiveSupport::TestCase
    def setup
      @original_helper_methods = AutoPreview.helper_methods
    end

    def teardown
      AutoPreview.helper_methods = @original_helper_methods
    end

    def test_ensure_methods_does_nothing_with_empty_overrides
      controller_class = Class.new(ActionController::Base)
      result = HelperOverrideHelper.ensure_methods(controller_class, {})
      assert_nil result
    end

    def test_ensure_methods_does_nothing_when_controller_has_no_helpers
      controller_class = Class.new
      user = User.new(name: "Test User", email: "test@example.com")
      result = HelperOverrideHelper.ensure_methods(controller_class, {"current_user" => user})
      assert_nil result
    end

    def test_ensure_methods_defines_helper_method_on_controller
      controller_class = Class.new(ActionController::Base)
      user = User.new(name: "Test User", email: "test@example.com")

      HelperOverrideHelper.ensure_methods(controller_class, {"current_user" => user})

      # The method should be defined in the helpers module
      assert controller_class._helpers.instance_methods.include?(:current_user)
    end

    def test_configured_helper_vars_returns_empty_when_no_config
      AutoPreview.helper_methods = {}

      result = HelperOverrideHelper.configured_helper_vars

      assert_equal({}, result)
    end

    def test_configured_helper_vars_returns_factory_type_for_symbol_hint
      AutoPreview.helper_methods = {current_user: :user}

      result = HelperOverrideHelper.configured_helper_vars

      assert_equal "Factory", result["current_user"]["type"]
      assert_equal "user", result["current_user"]["value"]
      assert result["current_user"]["helper"]
    end

    def test_configured_helper_vars_returns_boolean_type_for_boolean_hint
      AutoPreview.helper_methods = {premium_user?: :boolean}

      result = HelperOverrideHelper.configured_helper_vars

      assert_equal "Boolean", result["premium_user?"]["type"]
      assert_equal "true", result["premium_user?"]["value"]  # Predicate defaults to true
    end

    def test_configured_helper_vars_returns_string_type_for_string_hint
      AutoPreview.helper_methods = {site_name: :string}

      result = HelperOverrideHelper.configured_helper_vars

      assert_equal "String", result["site_name"]["type"]
      assert_equal "", result["site_name"]["value"]
    end

    def test_configured_helper_vars_returns_integer_type
      AutoPreview.helper_methods = {max_items: :integer}

      result = HelperOverrideHelper.configured_helper_vars

      assert_equal "Integer", result["max_items"]["type"]
      assert_equal "0", result["max_items"]["value"]
    end

    def test_configured_helper_vars_handles_mixed_types
      AutoPreview.helper_methods = {
        current_user: :user,
        premium?: :boolean,
        site_name: :string
      }

      result = HelperOverrideHelper.configured_helper_vars

      assert_equal 3, result.size
      assert_equal "Factory", result["current_user"]["type"]
      assert_equal "Boolean", result["premium?"]["type"]
      assert_equal "String", result["site_name"]["type"]
    end
  end
end
