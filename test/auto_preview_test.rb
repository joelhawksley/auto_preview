# frozen_string_literal: true

require "test_helper"
require "auto_preview/version"

class AutoPreviewTest < Minitest::Test
  include TestHelper

  def test_that_it_has_a_version_number
    refute_nil AutoPreview::VERSION
  end

  def test_renders_simple_erb_file
    result = AutoPreview.render(fixture_path("simple.erb"))
    assert_includes result, "Hello"
    assert_includes result, "[mock:name]"
  end

  def test_renders_erb_string
    result = AutoPreview.render_string("<p>Hello <%= name %></p>")
    assert_includes result, "Hello"
    assert_includes result, "[mock:name]"
  end

  def test_renders_with_provided_locals
    result = AutoPreview.render_string("<p>Hello <%= name %></p>", locals: { name: "World" })
    assert_includes result, "Hello World"
    refute_includes result, "[mock:"
  end

  def test_renders_with_mock_values
    result = AutoPreview.render_string("<p>Hello <%= user.name %></p>", mock_values: { user: OpenStruct.new(name: "Alice") })
    assert_includes result, "Hello Alice"
  end

  def test_raises_error_for_missing_file
    assert_raises AutoPreview::Error do
      AutoPreview.render("/nonexistent/file.erb")
    end
  end

  def test_raises_error_when_no_file_or_string_provided
    assert_raises AutoPreview::Error do
      AutoPreview::Renderer.new(nil).render
    end
  end

  def test_renderer_accessed_mocks_before_render
    renderer = AutoPreview::Renderer.new(nil, erb_string: "<%= name %>")
    assert_equal [], renderer.accessed_mocks
  end

  def test_renderer_accessed_mocks_after_render
    renderer = AutoPreview::Renderer.new(nil, erb_string: "<%= name %><%= age %>")
    renderer.render
    assert_includes renderer.accessed_mocks, :name
    assert_includes renderer.accessed_mocks, :age
  end

  def test_renders_complex_template
    products = [OpenStruct.new(name: "Product 1", price: 10, image_url: "img.png", description: "desc", in_stock?: true)]
    current_user = OpenStruct.new(name: "Test User")
    result = AutoPreview.render(
      fixture_path("complex.erb"),
      locals: { :@products => products, current_user: current_user }
    )
    assert_includes result, "<!DOCTYPE html>"
    assert_includes result, "<html>"
    assert_includes result, "</html>"
    assert_includes result, "Test User"
    assert_includes result, "Logout"
  end

  def test_renders_complex_template_without_current_user
    products = [OpenStruct.new(name: "Product 1", price: 10, image_url: "img.png", description: "desc", in_stock?: true)]
    result = AutoPreview.render(
      fixture_path("complex.erb"),
      locals: { :@products => products, current_user: nil }
    )
    assert_includes result, "Login"
  end

  def test_renders_complex_template_with_out_of_stock_product
    products = [OpenStruct.new(name: "Product 1", price: 10, image_url: "img.png", description: "desc", in_stock?: false)]
    result = AutoPreview.render(fixture_path("complex.erb"), locals: { :@products => products })
    assert_includes result, "Out of Stock"
    assert_includes result, "disabled"
  end
end
