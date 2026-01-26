# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class VariableExtractorTest < ActiveSupport::TestCase
    def test_extract_from_name_error
      error = NameError.new("undefined local variable or method `my_var' for main:Object")
      result = VariableExtractor.extract(error)
      assert_equal "my_var", result
    end

    def test_extract_from_no_method_error
      error = NoMethodError.new("undefined method `admin?' for an instance of SomeClass")
      result = VariableExtractor.extract(error)
      assert_equal "admin?", result
    end

    def test_extract_returns_nil_for_non_matching_error
      error = NameError.new("some completely different error format")
      result = VariableExtractor.extract(error)
      assert_nil result
    end

    def test_extract_handles_backtick_quotes
      error = NameError.new("undefined method `test_method' for main")
      result = VariableExtractor.extract(error)
      assert_equal "test_method", result
    end
  end
end
