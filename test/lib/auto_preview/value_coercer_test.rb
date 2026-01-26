# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class ValueCoercerTest < ActiveSupport::TestCase
    def test_coerce_string
      assert_equal "hello", ValueCoercer.coerce("hello", "String")
      assert_equal "123", ValueCoercer.coerce(123, "String")
    end

    def test_coerce_integer
      assert_equal 42, ValueCoercer.coerce("42", "Integer")
      assert_equal 0, ValueCoercer.coerce("not a number", "Integer")
    end

    def test_coerce_float
      assert_equal 3.14, ValueCoercer.coerce("3.14", "Float")
      assert_equal 0.0, ValueCoercer.coerce("not a number", "Float")
    end

    def test_coerce_boolean_true_values
      assert_equal true, ValueCoercer.coerce("true", "Boolean")
      assert_equal true, ValueCoercer.coerce("1", "Boolean")
      assert_equal true, ValueCoercer.coerce("yes", "Boolean")
      assert_equal true, ValueCoercer.coerce("YES", "Boolean")
    end

    def test_coerce_boolean_false_values
      assert_equal false, ValueCoercer.coerce("false", "Boolean")
      assert_equal false, ValueCoercer.coerce("anything", "Boolean")
      assert_equal false, ValueCoercer.coerce("0", "Boolean")
      assert_equal false, ValueCoercer.coerce("no", "Boolean")
    end

    def test_coerce_array
      assert_equal ["a", "b"], ValueCoercer.coerce('["a", "b"]', "Array")
      assert_equal [], ValueCoercer.coerce("invalid json", "Array")
      assert_equal [], ValueCoercer.coerce("", "Array")
    end

    def test_coerce_hash
      assert_equal({"key" => "value"}, ValueCoercer.coerce('{"key": "value"}', "Hash"))
      assert_equal({}, ValueCoercer.coerce("invalid json", "Hash"))
      assert_equal({}, ValueCoercer.coerce("", "Hash"))
    end

    def test_coerce_nil_class
      assert_nil ValueCoercer.coerce("anything", "NilClass")
    end

    def test_coerce_factory
      result = ValueCoercer.coerce("user", "Factory")
      assert_instance_of User, result
    end

    def test_coerce_unknown_type_defaults_to_string
      assert_equal "hello", ValueCoercer.coerce("hello", "UnknownType")
    end

    def test_parse_json_or_default_with_blank_value
      coercer = ValueCoercer.new
      assert_equal [1, 2], coercer.parse_json_or_default("", [1, 2])
      assert_equal({a: 1}, coercer.parse_json_or_default(nil, {a: 1}))
    end

    def test_parse_json_or_default_with_invalid_json
      coercer = ValueCoercer.new
      assert_equal [], coercer.parse_json_or_default("not json", [])
      assert_equal({}, coercer.parse_json_or_default("{invalid}", {}))
    end
  end
end
