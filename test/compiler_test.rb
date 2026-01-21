# frozen_string_literal: true

require "test_helper"

class CompilerTest < Minitest::Test
  include TestHelper

  def test_compiled_dir_returns_default_path
    # Reset to ensure we test the default
    AutoPreview::Compiler.instance_variable_set(:@compiled_dir, nil)
    dir = AutoPreview::Compiler.compiled_dir
    assert_includes dir, "auto_preview_compiled"
  end

  def test_compiled_dir_can_be_set
    original = AutoPreview::Compiler.compiled_dir
    AutoPreview::Compiler.compiled_dir = "/custom/path"
    assert_equal "/custom/path", AutoPreview::Compiler.compiled_dir
  ensure
    AutoPreview::Compiler.compiled_dir = original
  end

  def test_compile_with_source_path
    compiler = AutoPreview::Compiler.new(source_path: fixture_path("simple.erb"))
    compiled_path = compiler.compile
    assert File.exist?(compiled_path)
    content = File.read(compiled_path)
    assert_includes content, "Compiled from:"
    assert_includes content, "simple.erb"
  end

  def test_compile_with_erb_string
    compiler = AutoPreview::Compiler.new(erb_string: "<p>Hello <%= name %></p>")
    compiled_path = compiler.compile
    assert File.exist?(compiled_path)
    content = File.read(compiled_path)
    assert_includes content, "(string)"
  end

  def test_class_name_for_source_path
    compiler = AutoPreview::Compiler.new(source_path: fixture_path("simple.erb"))
    assert_match /Template_simple/, compiler.class_name
  end

  def test_class_name_for_erb_string
    compiler = AutoPreview::Compiler.new(erb_string: "<p>Test</p>")
    assert_match /Template_String/, compiler.class_name
  end

  def test_class_name_sanitizes_special_characters
    compiler = AutoPreview::Compiler.new(erb_string: "<p>Test</p>")
    # The class_name method sanitizes special characters
    name = compiler.class_name
    refute_match /[^a-zA-Z0-9_]/, name
  end

  def test_template_class_after_compile
    # Use a unique string to avoid conflicts
    unique_string = "<p>Test #{rand(10000)}</p>"
    compiler = AutoPreview::Compiler.new(erb_string: unique_string)
    compiler.compile
    # Manually load the compiled file
    load compiler.compiled_path
    template_class = compiler.template_class
    assert template_class.is_a?(Class)
    assert template_class.respond_to?(:render)
  end

  def test_raises_error_when_no_source_provided
    assert_raises AutoPreview::Error do
      AutoPreview::Compiler.new(source_path: nil, erb_string: nil).compile
    end
  end

  def test_raises_error_for_nonexistent_file
    assert_raises AutoPreview::Error do
      AutoPreview::Compiler.new(source_path: "/nonexistent/file.erb").compile
    end
  end

  def test_transform_local_assigns
    erb_string = <<~ERB
      <% issue ||= nil %>
      <% comment ||= starting_comment %>
      <%= issue.title %>
    ERB
    compiler = AutoPreview::Compiler.new(erb_string: erb_string)
    compiled_path = compiler.compile
    content = File.read(compiled_path)
    assert_includes content, "__auto_preview_local"
    assert_includes content, ":issue"
    assert_includes content, ":comment"
  end
end
