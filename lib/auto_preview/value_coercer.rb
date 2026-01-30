# frozen_string_literal: true

module AutoPreview
  # Coerces string values to their appropriate Ruby types
  class ValueCoercer
    def self.coerce(value, type)
      new.coerce(value, type)
    end

    def coerce(value, type)
      case type
      when "String"
        value.to_s
      when "Integer"
        value.to_i
      when "Float"
        value.to_f
      when "Boolean"
        %w[true 1 yes].include?(value.to_s.downcase)
      when "Array"
        parse_json_or_default(value, [])
      when "Hash"
        parse_json_or_default(value, {})
      when "NilClass"
        nil
      when "Factory"
        FactoryHelper.create(value)
      when "Proc"
        eval_ruby(value)
      else
        value.to_s
      end
    end

    def parse_json_or_default(value, default)
      return default if value.blank?

      JSON.parse(value)
    rescue JSON::ParserError
      default
    end

    def eval_ruby(value)
      return nil if value.blank?

      eval(value) # rubocop:disable Security/Eval
    rescue => e
      "Error: #{e.message}"
    end
  end
end
