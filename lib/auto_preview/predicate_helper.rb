# frozen_string_literal: true

module AutoPreview
  # Ensures predicate helper methods are defined on controller classes
  class PredicateHelper
    def self.ensure_methods(controller_class, predicate_methods)
      new.ensure_methods(controller_class, predicate_methods)
    end

    def ensure_methods(controller_class, predicate_methods)
      return if predicate_methods.empty?
      return unless controller_class.respond_to?(:_helpers)

      helpers_module = controller_class._helpers
      helper_module = Module.new

      predicate_methods.each_key do |method_name|
        method_sym = method_name.to_sym
        next if helpers_module.instance_methods.include?(method_sym)

        helper_module.define_method(method_sym) do
          (@_auto_preview_predicates || {})[method_name]
        end
      end

      controller_class.helper(helper_module) if helper_module.instance_methods.any?
    end
  end
end
