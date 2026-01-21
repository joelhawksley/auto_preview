# frozen_string_literal: true

require "test_helper"
require "auto_preview/const_stub"

class ConstStubTest < Minitest::Test
  def test_create_const_stub_without_parent
    stub = AutoPreview::CompiledTemplates.create_const_stub
    assert stub.is_a?(Class)
    assert_nil stub.parent_name
  end

  def test_create_const_stub_with_parent
    stub = AutoPreview::CompiledTemplates.create_const_stub("ParentModule")
    assert_equal "ParentModule", stub.parent_name
  end

  def test_const_stub_full_name_with_parent
    stub = AutoPreview::CompiledTemplates.create_const_stub("MyModule")
    # Give the stub a name by assigning it to a constant
    Object.const_set(:TestStubA, stub)
    begin
      assert_match /MyModule::TestStubA/, stub.full_name
    ensure
      Object.send(:remove_const, :TestStubA)
    end
  end

  def test_const_stub_full_name_without_parent
    stub = AutoPreview::CompiledTemplates.create_const_stub
    Object.const_set(:TestStubB, stub)
    begin
      assert_equal "TestStubB", stub.full_name
    ensure
      Object.send(:remove_const, :TestStubB)
    end
  end

  def test_const_stub_method_missing_returns_mock_value
    stub = AutoPreview::CompiledTemplates.create_const_stub("MyClass")
    result = stub.some_method("arg")
    assert result.is_a?(AutoPreview::MockContext::MockValue)
  end

  def test_const_stub_respond_to_missing
    stub = AutoPreview::CompiledTemplates.create_const_stub
    assert stub.respond_to?(:any_method)
    assert stub.respond_to?(:another_method, true)
  end

  def test_const_stub_const_missing_creates_nested_stub
    stub = AutoPreview::CompiledTemplates.create_const_stub("Parent")
    child = stub::NestedConst
    assert child.is_a?(Class)
    # Accessing again should return the same constant
    assert_equal child, stub::NestedConst
  end

  def test_const_stub_new_returns_mock_value
    stub = AutoPreview::CompiledTemplates.create_const_stub("MyClass")
    instance = stub.new("arg", key: "value")
    assert instance.is_a?(AutoPreview::MockContext::MockValue)
  end

  def test_const_stub_new_with_block
    stub = AutoPreview::CompiledTemplates.create_const_stub("MyClass")
    instance = stub.new { "block content" }
    assert instance.is_a?(AutoPreview::MockContext::MockValue)
  end

  def test_anonymous_stub_new
    stub = AutoPreview::CompiledTemplates.create_const_stub
    # Don't assign to constant - test anonymous path
    instance = stub.new
    assert instance.is_a?(AutoPreview::MockContext::MockValue)
    # The mock should have a path containing "anonymous"
    assert_match /anonymous/, instance.to_s
  end
end
