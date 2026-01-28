# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class ComponentScannerTest < ActiveSupport::TestCase
    def test_scan_extracts_initialize_parameters
      params = ComponentScanner.scan(ButtonComponent)

      assert_equal 3, params.size

      label_param = params.find { |p| p[:name] == "label" }
      assert label_param
      assert label_param[:required]
      assert label_param[:keyword]

      variant_param = params.find { |p| p[:name] == "variant" }
      assert variant_param
      refute variant_param[:required]
      assert variant_param[:keyword]

      disabled_param = params.find { |p| p[:name] == "disabled" }
      assert disabled_param
      refute disabled_param[:required]
      assert disabled_param[:keyword]
    end

    def test_scan_returns_empty_array_for_class_without_initialize
      # Create a simple class without explicit initialize
      klass = Class.new(ViewComponent::Base)
      params = ComponentScanner.scan(klass)
      assert_equal [], params
    end

    def test_scan_handles_class_without_instance_method
      # Object that doesn't respond to instance_method
      result = ComponentScanner.scan("not a class")
      assert_equal [], result
    end

    def test_find_components_returns_view_components
      components = ComponentScanner.find_components

      button = components.find { |c| c[:name] == "ButtonComponent" }
      assert button, "Expected to find ButtonComponent"
      assert button[:params].any? { |p| p[:name] == "label" }
    end

    def test_find_components_returns_empty_when_view_component_not_defined
      # Temporarily remove ViewComponent constant
      original = ViewComponent::Base
      ViewComponent.send(:remove_const, :Base)

      result = ComponentScanner.find_components
      assert_equal [], result
    ensure
      ViewComponent.const_set(:Base, original)
    end
  end
end
