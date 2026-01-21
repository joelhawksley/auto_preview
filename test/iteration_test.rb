# frozen_string_literal: true

require "test_helper"

class IterationTest < Minitest::Test
  include TestHelper

  def test_each_with_mocked_collection
    result = AutoPreview.render_string(
      "<% items.each do |item| %><li><%= item.name %></li><% end %>"
    )
    # Mocked collections are empty by default
    refute_includes result, "<li>"
  end

  def test_each_with_provided_collection
    items = [
      OpenStruct.new(name: "Apple"),
      OpenStruct.new(name: "Banana")
    ]
    result = AutoPreview.render_string(
      "<% items.each do |item| %><li><%= item.name %></li><% end %>",
      locals: { items: items }
    )
    assert_includes result, "<li>Apple</li>"
    assert_includes result, "<li>Banana</li>"
  end

  def test_map_with_mocked_collection
    result = AutoPreview.render_string(
      "<%= items.map { |i| i.name }.join(', ') %>"
    )
    # Mocked map returns empty array
    assert_equal "", result.strip
  end

  def test_iteration_with_mock_values
    items = [{ name: "Item 1" }, { name: "Item 2" }]
    result = AutoPreview.render_string(
      "<% items.each do |item| %><span><%= item[:name] %></span><% end %>",
      mock_values: { items: items }
    )
    assert_includes result, "Item 1"
    assert_includes result, "Item 2"
  end
end
