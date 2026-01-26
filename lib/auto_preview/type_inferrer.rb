# frozen_string_literal: true

module AutoPreview
  # Infers type and default value from variable names based on naming conventions
  class TypeInferrer
    def self.infer(variable_name)
      new.infer(variable_name)
    end

    def infer(variable_name)
      name = variable_name.to_s

      # Predicate methods (ends with ?)
      if name.end_with?("?")
        return ["Boolean", "true"]
      end

      # Check if there's a matching factory
      if defined?(FactoryBot)
        factory_name = name.singularize
        if FactoryBot.factories.any? { |f| f.name.to_s == factory_name }
          return ["Factory", factory_name]
        end
      end

      # Infer type from common naming patterns
      case name
      when /^(is_|has_|can_|should_|enable|disable|show|hide|allow|active|visible|confirmed|verified|valid)/
        ["Boolean", "true"]
      when /(_id|_count|count|number|age|year|index|position|quantity|amount|total|size|length)$/
        ["Integer", "42"]
      when /(_price|_rate|_amount|price|rate|cost|percentage|ratio)$/
        ["Float", "19.99"]
      when /(_at|_on|_date|date|time|timestamp)$/
        ["String", Time.now.iso8601]
      when /(_url|url|link|href)$/
        ["String", "https://example.com"]
      when /(email|mail)$/
        ["String", "user@example.com"]
      when /(name|title|label)$/
        ["String", "Example #{name.humanize}"]
      when /(description|body|content|text|message|comment)$/
        ["String", "This is sample #{name.humanize.downcase} content."]
      when /(_items|_list|items|list|tags|options|values|records|collection)$/
        ["Array", "[]"]
      when /(_data|_config|_options|_settings|data|config|options|settings|attributes|params|metadata)$/
        ["Hash", "{}"]
      when /(user|admin|author|owner|creator|member|person|customer|client|employee|manager)/
        # Check for user factory specifically
        if defined?(FactoryBot) && FactoryBot.factories.any? { |f| f.name.to_s == "user" }
          ["Factory", "user"]
        else
          ["String", "John Doe"]
        end
      else
        # Default to String with a human-readable placeholder
        ["String", "Sample #{name.humanize}"]
      end
    end
  end
end
