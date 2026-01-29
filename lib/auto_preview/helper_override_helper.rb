# frozen_string_literal: true

module AutoPreview
  # Overrides helper methods on controller classes to return configured values.
  # This allows host applications to define helper methods in an initializer
  # that can be configured in the UI and overridden when rendering templates.
  #
  # Example configuration in initializer:
  #   AutoPreview.helper_methods = {
  #     current_user: :user,  # Factory-backed helper
  #     feature_enabled?: :boolean
  #   }
  class HelperOverrideHelper
    def self.ensure_methods(controller_class, helper_overrides)
      new.ensure_methods(controller_class, helper_overrides)
    end

    def self.configured_helper_vars
      new.configured_helper_vars
    end

    def ensure_methods(controller_class, helper_overrides)
      return if helper_overrides.empty?
      return unless controller_class.respond_to?(:_helpers)

      helper_module = Module.new

      helper_overrides.each do |method_name, value|
        method_sym = method_name.to_sym

        # Define method that returns the configured value
        helper_module.define_method(method_sym) do
          @_auto_preview_helper_overrides ||= {}
          @_auto_preview_helper_overrides[method_name.to_s]
        end
      end

      controller_class.helper(helper_module) if helper_module.instance_methods.any?
    end

    # Convert configured helper_methods into vars format for the UI
    # Returns a hash of helper method names to their default configs
    def configured_helper_vars
      vars = {}
      return vars unless AutoPreview.helper_methods.is_a?(Hash)

      AutoPreview.helper_methods.each do |method_name, type_hint|
        type, default_value = infer_type_and_default(type_hint, method_name.to_s)
        vars[method_name.to_s] = {"type" => type, "value" => default_value, "helper" => true}
      end

      vars
    end

    private

    def infer_type_and_default(type_hint, method_name)
      case type_hint
      when :boolean, "boolean", "Boolean"
        ["Boolean", method_name.end_with?("?") ? "true" : "false"]
      when :string, "string", "String"
        ["String", ""]
      when :integer, "integer", "Integer"
        ["Integer", "0"]
      when :float, "float", "Float"
        ["Float", "0.0"]
      when :array, "array", "Array"
        ["Array", "[]"]
      when :hash, "hash", "Hash"
        ["Hash", "{}"]
      when Symbol, String
        # Assume it's a factory name
        ["Factory", type_hint.to_s]
      else
        ["String", ""]
      end
    end
  end
end
