# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class PredicateHelperTest < ActiveSupport::TestCase
    def test_ensure_methods_skips_when_empty
      assert_nothing_raised do
        PredicateHelper.ensure_methods(ApplicationController, {})
      end
    end

    def test_ensure_methods_skips_when_no_helpers
      mock_class = Class.new

      assert_nothing_raised do
        PredicateHelper.ensure_methods(mock_class, {"test?" => true})
      end
    end
  end
end
