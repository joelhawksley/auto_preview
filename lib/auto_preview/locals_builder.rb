# frozen_string_literal: true

module AutoPreview
  # Builds locals hashes from params and adds auto-generated values
  class LocalsBuilder
    def self.build_locals(vars_params)
      new.build_locals(vars_params)
    end

    def self.build_predicates(vars_params)
      new.build_predicates(vars_params)
    end

    def self.add_auto_generated_value(vars, variable_name)
      new.add_auto_generated_value(vars, variable_name)
    end

    def self.extract_provided_names(vars_params)
      new.extract_provided_names(vars_params)
    end

    def build_locals(vars_params)
      locals = {}
      return locals unless vars_params.is_a?(ActionController::Parameters) || vars_params.is_a?(Hash)

      vars_params.each do |name, config|
        next unless config.is_a?(ActionController::Parameters) || config.is_a?(Hash)
        # Skip predicate methods - they're handled separately as helper methods
        next if name.to_s.end_with?("?")
        # Skip instance variables - they're handled separately as assigns
        next if name.to_s.start_with?("@")

        type = config[:type] || config["type"]
        value = config[:value] || config["value"]
        locals[name.to_sym] = ValueCoercer.coerce(value, type)
      end

      locals
    end

    def build_predicates(vars_params)
      predicates = {}
      return predicates unless vars_params.is_a?(ActionController::Parameters) || vars_params.is_a?(Hash)

      vars_params.each do |name, config|
        next unless name.to_s.end_with?("?")
        next unless config.is_a?(ActionController::Parameters) || config.is_a?(Hash)

        type = config[:type] || config["type"] || "Boolean"
        value = config[:value] || config["value"]
        predicates[name.to_s] = ValueCoercer.coerce(value, type)
      end

      predicates
    end

    def add_auto_generated_value(vars, variable_name)
      if vars.respond_to?(:to_unsafe_h)
        vars = vars.to_unsafe_h.deep_dup
      elsif vars.is_a?(Hash)
        vars = vars.deep_dup
      else
        vars = {}
      end
      type, value = TypeInferrer.infer(variable_name)
      vars[variable_name] = {"type" => type, "value" => value}
      vars
    end

    def extract_provided_names(vars_params)
      return [] unless vars_params.is_a?(ActionController::Parameters) || vars_params.is_a?(Hash)

      vars_params.keys.map(&:to_s)
    end
  end
end
