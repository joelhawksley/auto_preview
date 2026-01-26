# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class FactoryHelperTest < ActiveSupport::TestCase
    def test_create_returns_nil_when_value_blank
      assert_nil FactoryHelper.create("")
      assert_nil FactoryHelper.create(nil)
    end

    def test_create_returns_factory_instance
      result = FactoryHelper.create("user")
      assert_instance_of User, result
    end

    def test_create_with_traits
      result = FactoryHelper.create("user:admin")
      assert_instance_of User, result
      assert_equal "Admin User", result.name
    end

    def test_create_without_factory_bot_defined
      original_factory_bot = Object.send(:remove_const, :FactoryBot)
      begin
        result = FactoryHelper.create("user")
        assert_nil result
      ensure
        Object.const_set(:FactoryBot, original_factory_bot)
      end
    end

    def test_all_returns_factories_with_traits
      factories = FactoryHelper.all
      user_factory = factories.find { |f| f[:name] == "user" }
      assert_not_nil user_factory
      assert_includes user_factory[:traits], "admin"
    end

    def test_all_without_factory_bot_defined
      original_factory_bot = Object.send(:remove_const, :FactoryBot)
      begin
        result = FactoryHelper.all
        assert_equal [], result
      ensure
        Object.const_set(:FactoryBot, original_factory_bot)
      end
    end
  end
end
