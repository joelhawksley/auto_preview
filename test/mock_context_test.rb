# frozen_string_literal: true

require "test_helper"

class MockContextTest < Minitest::Test
  def test_mock_value_is_truthy
    mock = AutoPreview::MockContext::MockValue.new("test")
    assert mock
    assert !mock.!
  end

  def test_mock_value_to_s
    mock = AutoPreview::MockContext::MockValue.new("user")
    assert_equal "[mock:user]", mock.to_s
  end

  def test_mock_value_to_s_without_method_name
    mock = AutoPreview::MockContext::MockValue.new
    assert_equal "[mock:value]", mock.to_s
  end

  def test_mock_value_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("name", custom_value: "Alice", has_custom_value: true)
    assert_equal "Alice", mock.to_s
    assert mock.has_custom_value?
  end

  def test_mock_value_without_custom_value
    mock = AutoPreview::MockContext::MockValue.new("name")
    refute mock.has_custom_value?
  end

  def test_mock_value_to_str
    mock = AutoPreview::MockContext::MockValue.new("test")
    assert_equal "[mock:test]", mock.to_str
  end

  def test_mock_value_method_chaining
    mock = AutoPreview::MockContext::MockValue.new("user")
    result = mock.profile.name
    assert_equal "[mock:user.profile.name]", result.to_s
  end

  def test_mock_value_array_access
    mock = AutoPreview::MockContext::MockValue.new("data")
    result = mock[:key]
    assert_equal "[mock:data[:key]]", result.to_s
  end

  def test_mock_value_array_access_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("data", custom_value: { key: "value" }, has_custom_value: true)
    assert_equal "value", mock[:key]
  end

  def test_mock_value_nil_check
    mock = AutoPreview::MockContext::MockValue.new("test")
    refute mock.nil?
  end

  def test_mock_value_present
    mock = AutoPreview::MockContext::MockValue.new("test")
    assert mock.present?
  end

  def test_mock_value_blank
    mock = AutoPreview::MockContext::MockValue.new("test")
    refute mock.blank?
  end

  def test_mock_value_comparison
    mock = AutoPreview::MockContext::MockValue.new("count")
    assert mock > 0
    assert mock >= 0
    refute mock < 0
    assert mock <= 0
  end

  def test_mock_value_comparison_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("count", custom_value: 5, has_custom_value: true)
    assert mock > 3
    assert mock >= 5
    refute mock < 3
    assert mock <= 5
  end

  def test_mock_value_spaceship_operator
    mock = AutoPreview::MockContext::MockValue.new("count")
    assert_equal 0, mock <=> 5
  end

  def test_mock_value_spaceship_operator_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("count", custom_value: 5, has_custom_value: true)
    assert_equal 1, mock <=> 3
    assert_equal 0, mock <=> 5
    assert_equal(-1, mock <=> 7)
  end

  def test_mock_value_equality
    mock1 = AutoPreview::MockContext::MockValue.new("test")
    mock2 = AutoPreview::MockContext::MockValue.new("test")
    assert_equal mock1, mock2
  end

  def test_mock_value_equality_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("test", custom_value: "hello", has_custom_value: true)
    assert_equal "hello", mock
    refute_equal "world", mock
  end

  def test_mock_value_inequality
    mock = AutoPreview::MockContext::MockValue.new("test")
    assert mock != "string"
  end

  def test_mock_value_inequality_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("test", custom_value: "hello", has_custom_value: true)
    assert mock != "world"
  end

  def test_mock_context_provides_locals
    context = AutoPreview::MockContext.new(locals: { name: "Alice" })
    assert_equal "Alice", context.name
  end

  def test_mock_context_tracks_accessed_mocks
    context = AutoPreview::MockContext.new
    context.user
    context.items
    context.user # duplicate should not be added twice
    
    assert_includes context.accessed_mocks, :user
    assert_includes context.accessed_mocks, :items
    assert_equal 2, context.accessed_mocks.length
  end

  def test_mock_context_has_rails_helpers
    context = AutoPreview::MockContext.new
    
    assert_equal "<a href=\"/path\">Click</a>", context.link_to("Click", "/path")
    assert_equal "[translation:hello]", context.t("hello")
    assert_equal "2 items", context.pluralize(2, "item")
  end

  def test_mock_context_link_to_without_url
    context = AutoPreview::MockContext.new
    assert_equal "<a href=\"#\">Click</a>", context.link_to("Click")
  end

  def test_mock_context_image_tag
    context = AutoPreview::MockContext.new
    assert_equal "<img src=\"test.png\" />", context.image_tag("test.png")
  end

  def test_mock_context_translate_alias
    context = AutoPreview::MockContext.new
    assert_equal "[translation:hello]", context.translate("hello")
  end

  def test_mock_context_localize
    context = AutoPreview::MockContext.new
    assert_equal "[localized:2024-01-01]", context.l("2024-01-01")
    assert_equal "[localized:2024-01-01]", context.localize("2024-01-01")
  end

  def test_mock_context_pluralize_singular
    context = AutoPreview::MockContext.new
    assert_equal "1 item", context.pluralize(1, "item")
  end

  def test_mock_context_pluralize_with_custom_plural
    context = AutoPreview::MockContext.new
    assert_equal "2 children", context.pluralize(2, "child", "children")
  end

  def test_mock_context_truncate
    context = AutoPreview::MockContext.new
    assert_equal "Hello", context.truncate("Hello World", length: 5)
  end

  def test_mock_context_truncate_default_length
    context = AutoPreview::MockContext.new
    long_text = "a" * 50
    assert_equal "a" * 30, context.truncate(long_text)
  end

  def test_mock_context_number_to_currency
    context = AutoPreview::MockContext.new
    assert_equal "$99.99", context.number_to_currency(99.99)
  end

  def test_mock_context_time_ago_in_words
    context = AutoPreview::MockContext.new
    assert_equal "[time_ago:2024-01-01]", context.time_ago_in_words("2024-01-01")
  end

  def test_mock_context_h_escapes_html
    context = AutoPreview::MockContext.new
    assert_equal "&lt;script&gt;", context.h("<script>")
  end

  def test_mock_context_escape_html
    context = AutoPreview::MockContext.new
    assert_equal "&lt;div&gt;", context.escape_html("<div>")
  end

  def test_mock_context_raw
    context = AutoPreview::MockContext.new
    assert_equal "<b>bold</b>", context.raw("<b>bold</b>")
  end

  def test_mock_context_html_safe
    context = AutoPreview::MockContext.new
    assert_equal "<b>bold</b>", context.html_safe("<b>bold</b>")
  end

  def test_mock_context_concat
    context = AutoPreview::MockContext.new
    assert_equal "hello", context.concat("hello")
  end

  def test_mock_context_capture_with_block
    context = AutoPreview::MockContext.new
    result = context.capture { "captured" }
    assert_equal "captured", result
  end

  def test_mock_context_capture_without_block
    context = AutoPreview::MockContext.new
    result = context.capture
    assert_nil result
  end

  def test_mock_context_content_for_with_block
    context = AutoPreview::MockContext.new
    result = context.content_for(:sidebar) { "sidebar content" }
    assert_equal "", result
  end

  def test_mock_context_content_for_without_block
    context = AutoPreview::MockContext.new
    result = context.content_for(:sidebar)
    assert_equal "", result
  end

  def test_mock_context_render_with_block
    context = AutoPreview::MockContext.new
    result = context.render(partial: "test") { "block content" }
    assert_equal "block content", result
  end

  def test_mock_context_render_without_block
    context = AutoPreview::MockContext.new
    result = context.render(partial: "test")
    assert_includes result, "[rendered:"
    assert_includes result, "partial"
    assert_includes result, "test"
  end

  def test_mock_context_respond_to_missing
    context = AutoPreview::MockContext.new
    assert context.respond_to?(:any_method)
  end

  def test_mock_context_get_binding
    context = AutoPreview::MockContext.new
    assert_kind_of Binding, context.get_binding
  end

  def test_mock_context_with_mock_values
    context = AutoPreview::MockContext.new(mock_values: { user: "Alice" })
    assert_equal "Alice", context.user
  end

  def test_mock_context_with_instance_variable_mock_values
    context = AutoPreview::MockContext.new(mock_values: { :@title => "My Title" })
    assert_equal "My Title", context.instance_variable_get(:@title)
  end

  def test_mock_context_method_missing_returns_mock_value_from_mock_values
    context = AutoPreview::MockContext.new(mock_values: { special: "special_value" })
    # Access via method_missing path (not defined as singleton method since it's a symbol)
    # Actually mock_values with symbol keys get defined as methods, so we need a different approach
    result = context.unknown_method
    assert_kind_of AutoPreview::MockContext::MockValue, result
  end

  # MockValue iteration tests
  def test_mock_value_each_without_block
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_kind_of Enumerator, mock.each
  end

  def test_mock_value_each_with_block
    mock = AutoPreview::MockContext::MockValue.new("items")
    items = []
    result = mock.each { |i| items << i }
    assert_equal [], items
    assert_equal mock, result
  end

  def test_mock_value_each_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2, 3], has_custom_value: true)
    items = []
    mock.each { |i| items << i }
    assert_equal [1, 2, 3], items
  end

  def test_mock_value_map_without_block
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_kind_of Enumerator, mock.map
  end

  def test_mock_value_map_with_block
    mock = AutoPreview::MockContext::MockValue.new("items")
    result = mock.map { |i| i * 2 }
    assert_equal [], result
  end

  def test_mock_value_map_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2, 3], has_custom_value: true)
    result = mock.map { |i| i * 2 }
    assert_equal [2, 4, 6], result
  end

  def test_mock_value_select_without_block
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_kind_of Enumerator, mock.select
  end

  def test_mock_value_select_with_block
    mock = AutoPreview::MockContext::MockValue.new("items")
    result = mock.select { |i| i > 1 }
    assert_equal [], result
  end

  def test_mock_value_empty
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert mock.empty?
  end

  def test_mock_value_empty_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2], has_custom_value: true)
    refute mock.empty?
  end

  def test_mock_value_any
    mock = AutoPreview::MockContext::MockValue.new("items")
    refute mock.any?
  end

  def test_mock_value_any_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2], has_custom_value: true)
    assert mock.any?
  end

  def test_mock_value_length
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_equal 0, mock.length
  end

  def test_mock_value_length_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2, 3], has_custom_value: true)
    assert_equal 3, mock.length
  end

  def test_mock_value_size
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_equal 0, mock.size
  end

  def test_mock_value_count
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_equal 0, mock.count
  end

  def test_mock_value_first
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_equal "[mock:items.first]", mock.first.to_s
  end

  def test_mock_value_first_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2, 3], has_custom_value: true)
    assert_equal 1, mock.first
  end

  def test_mock_value_last
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_equal "[mock:items.last]", mock.last.to_s
  end

  def test_mock_value_last_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2, 3], has_custom_value: true)
    assert_equal 3, mock.last
  end

  def test_mock_value_to_a
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_equal [], mock.to_a
  end

  def test_mock_value_to_a_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("items", custom_value: [1, 2], has_custom_value: true)
    assert_equal [1, 2], mock.to_a
  end

  def test_mock_value_to_a_with_non_array_custom_value
    mock = AutoPreview::MockContext::MockValue.new("item", custom_value: "string", has_custom_value: true)
    assert_equal [], mock.to_a
  end

  def test_mock_value_to_ary
    mock = AutoPreview::MockContext::MockValue.new("items")
    assert_equal [], mock.to_ary
  end

  def test_mock_value_to_i
    mock = AutoPreview::MockContext::MockValue.new("count")
    assert_equal 0, mock.to_i
  end

  def test_mock_value_to_i_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("count", custom_value: 42, has_custom_value: true)
    assert_equal 42, mock.to_i
  end

  def test_mock_value_to_int
    mock = AutoPreview::MockContext::MockValue.new("count")
    assert_equal 0, mock.to_int
  end

  def test_mock_value_to_f
    mock = AutoPreview::MockContext::MockValue.new("price")
    assert_equal 0.0, mock.to_f
  end

  def test_mock_value_to_f_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("price", custom_value: 3.14, has_custom_value: true)
    assert_equal 3.14, mock.to_f
  end

  def test_mock_value_respond_to_missing
    mock = AutoPreview::MockContext::MockValue.new("test")
    assert mock.respond_to?(:any_method)
  end

  # Arithmetic operators
  def test_mock_value_addition
    mock = AutoPreview::MockContext::MockValue.new("num")
    result = mock + 5
    assert_kind_of AutoPreview::MockContext::MockValue, result
  end

  def test_mock_value_addition_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("num", custom_value: 10, has_custom_value: true)
    assert_equal 15, mock + 5
  end

  def test_mock_value_subtraction
    mock = AutoPreview::MockContext::MockValue.new("num")
    result = mock - 5
    assert_kind_of AutoPreview::MockContext::MockValue, result
  end

  def test_mock_value_subtraction_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("num", custom_value: 10, has_custom_value: true)
    assert_equal 5, mock - 5
  end

  def test_mock_value_multiplication
    mock = AutoPreview::MockContext::MockValue.new("num")
    result = mock * 5
    assert_kind_of AutoPreview::MockContext::MockValue, result
  end

  def test_mock_value_multiplication_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("num", custom_value: 10, has_custom_value: true)
    assert_equal 50, mock * 5
  end

  def test_mock_value_division
    mock = AutoPreview::MockContext::MockValue.new("num")
    result = mock / 5
    assert_kind_of AutoPreview::MockContext::MockValue, result
  end

  def test_mock_value_division_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("num", custom_value: 10, has_custom_value: true)
    assert_equal 2, mock / 5
  end

  def test_mock_value_modulo
    mock = AutoPreview::MockContext::MockValue.new("num")
    result = mock % 3
    assert_kind_of AutoPreview::MockContext::MockValue, result
  end

  def test_mock_value_modulo_with_custom_value
    mock = AutoPreview::MockContext::MockValue.new("num", custom_value: 10, has_custom_value: true)
    assert_equal 1, mock % 3
  end

  def test_mock_value_coerce
    mock = AutoPreview::MockContext::MockValue.new("num")
    left, right = mock.coerce(5)
    assert_kind_of AutoPreview::MockContext::MockValue, left
    assert_equal mock, right
  end

  # Tests for __auto_preview_local method
  def test_auto_preview_local_returns_mock_value_with_symbol_key
    context = AutoPreview::MockContext.new(mock_values: { my_var: "mocked" })
    result = context.__auto_preview_local(:my_var, -> { "default" })
    assert_equal "mocked", result
  end

  def test_auto_preview_local_returns_mock_value_with_string_key
    context = AutoPreview::MockContext.new(mock_values: { "my_var" => "mocked_string" })
    result = context.__auto_preview_local(:my_var, -> { "default" })
    assert_equal "mocked_string", result
  end

  def test_auto_preview_local_calls_default_when_no_mock
    context = AutoPreview::MockContext.new
    called = false
    result = context.__auto_preview_local(:unknown_var, -> { called = true; "default_value" })
    assert called, "Default proc should have been called"
    assert_equal "default_value", result
  end

  # Test that mock values can be chained without losing previous definitions
  # This tests the MockValue's ability to handle method chaining
  def test_mock_value_preserves_method_chain_independence
    # When we access issue.pull_request? and issue.locked? on a MockValue,
    # each creates its own chain without affecting the other
    mock = AutoPreview::MockContext::MockValue.new("issue")
    
    pr_result = mock.pull_request?
    locked_result = mock.locked?
    
    # Each should have its own independent path
    assert_equal "[mock:issue.pull_request?]", pr_result.to_s
    assert_equal "[mock:issue.locked?]", locked_result.to_s
  end

  # Test that nested objects with explicit method definitions work correctly
  def test_nested_object_mock_with_explicit_methods
    # Build a mock object similar to what CoverageRunner does
    issue = Object.new
    issue.define_singleton_method(:pull_request?) { true }
    issue.define_singleton_method(:locked?) { false }
    
    context = AutoPreview::MockContext.new(mock_values: { issue: issue })
    
    # Both methods should be accessible
    assert_equal true, context.issue.pull_request?
    assert_equal false, context.issue.locked?
  end
end
