# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class LocalsBuilderTest < ActiveSupport::TestCase
    def test_build_locals_from_params
      vars_params = ActionController::Parameters.new({
        name: {type: "String", value: "Alice"},
        count: {type: "Integer", value: "42"}
      })

      result = LocalsBuilder.build_locals(vars_params)

      assert_equal "Alice", result[:name]
      assert_equal 42, result[:count]
    end

    def test_build_locals_skips_invalid_config_format
      vars_params = ActionController::Parameters.new({name: "just a string, not a hash"})

      result = LocalsBuilder.build_locals(vars_params)
      assert_equal({}, result)
    end

    def test_build_locals_returns_empty_for_nil
      result = LocalsBuilder.build_locals(nil)
      assert_equal({}, result)
    end

    def test_build_locals_skips_predicates
      vars_params = ActionController::Parameters.new({
        "active?": {type: "Boolean", value: "true"},
        name: {type: "String", value: "Test"}
      })

      result = LocalsBuilder.build_locals(vars_params)
      assert_equal({name: "Test"}, result)
    end

    def test_build_predicates
      vars_params = ActionController::Parameters.new({
        "premium_user?": {type: "Boolean", value: "true"},
        "admin?": {type: "Boolean", value: "false"},
        regular_var: {type: "String", value: "hello"}
      })

      result = LocalsBuilder.build_predicates(vars_params)

      assert_equal true, result["premium_user?"]
      assert_equal false, result["admin?"]
      refute result.key?("regular_var")
    end

    def test_build_predicates_returns_empty_for_nil
      result = LocalsBuilder.build_predicates(nil)
      assert_equal({}, result)
    end

    def test_build_predicates_skips_invalid_config
      vars_params = ActionController::Parameters.new({
        "predicate?": "not a hash"
      })

      result = LocalsBuilder.build_predicates(vars_params)
      assert_equal({}, result)
    end

    def test_add_auto_generated_value
      vars = {"existing" => {"type" => "String", "value" => "test"}}

      result = LocalsBuilder.add_auto_generated_value(vars, "user_id")

      assert_equal "String", result["existing"]["type"]
      assert_equal "Integer", result["user_id"]["type"]
      assert_equal "42", result["user_id"]["value"]
    end

    def test_add_auto_generated_value_with_action_controller_params
      vars = ActionController::Parameters.new({
        existing: {type: "String", value: "test"}
      })

      result = LocalsBuilder.add_auto_generated_value(vars, "user_name")

      assert result.is_a?(Hash)
      assert_equal "String", result["user_name"]["type"]
    end

    def test_add_auto_generated_value_with_non_hash
      result = LocalsBuilder.add_auto_generated_value("invalid", "user_id")

      assert result.is_a?(Hash)
      assert_equal "Integer", result["user_id"]["type"]
    end

    def test_extract_provided_names
      vars_params = ActionController::Parameters.new({
        name: {type: "String", value: "test"},
        count: {type: "Integer", value: "42"}
      })

      result = LocalsBuilder.extract_provided_names(vars_params)

      assert_includes result, "name"
      assert_includes result, "count"
    end

    def test_extract_provided_names_returns_empty_for_invalid_params
      assert_equal [], LocalsBuilder.extract_provided_names(nil)
      assert_equal [], LocalsBuilder.extract_provided_names("not a hash")
    end

    def test_build_locals_skips_instance_variables
      vars_params = ActionController::Parameters.new({
        "@current_user": {type: "Factory", value: "user"},
        name: {type: "String", value: "Test"}
      })

      result = LocalsBuilder.build_locals(vars_params)

      refute result.key?(:@current_user)
      refute result.key?(:"@current_user")
      assert_equal "Test", result[:name]
    end
  end
end
