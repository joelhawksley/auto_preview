# frozen_string_literal: true

module AutoPreview
  # Generates presets that cover all branches in a template by analyzing conditionals.
  # Each preset sets variables such that different branches are exercised.
  class PresetGenerator
    CONDITIONAL_PATTERNS = [
      # if/unless with predicate method (e.g., <% if premium_user? %>)
      /<%-?\s*if\s+(\w+\??)\s*%>/,
      /<%-?\s*unless\s+(\w+\??)\s*%>/,
      # if/unless with variable (e.g., <% if show_header %>)
      /<%-?\s*if\s+(\w+)\s*%>/,
      /<%-?\s*unless\s+(\w+)\s*%>/,
      # Ternary with predicate (e.g., <%= admin? ? "Admin" : "User" %>)
      /<%=?\s*(\w+\??)\s*\?\s*[^:]+\s*:\s*[^%]+%>/,
      # if modifier (e.g., <%= content if show_content? %>)
      /<%=?\s*\S+.*\s+if\s+(\w+\??)\s*%>/,
      /<%=?\s*\S+.*\s+unless\s+(\w+\??)\s*%>/
    ].freeze

    class << self
      # Generate presets for a template that together cover all branches
      # @param template_source [String] The ERB template source code
      # @param existing_vars [Hash] Currently known variables and their types
      # @return [Array<Hash>] Array of preset configurations
      def generate(template_source, existing_vars = {})
        conditionals = extract_conditionals(template_source)
        return [] if conditionals.empty?

        # Group conditionals that control different branches
        generate_covering_presets(conditionals, existing_vars)
      end

      private

      def extract_conditionals(source)
        conditionals = []

        # Track line numbers for each conditional
        source.lines.each_with_index do |line, index|
          line_num = index + 1

          # Check for if statements
          if line =~ /<%-?\s*if\s+(\w+\??)\s*%>/
            var_name = $1
            conditionals << {
              name: var_name,
              line: line_num,
              type: :if,
              is_predicate: var_name.end_with?("?")
            }
          end

          # Check for unless statements
          if line =~ /<%-?\s*unless\s+(\w+\??)\s*%>/
            var_name = $1
            conditionals << {
              name: var_name,
              line: line_num,
              type: :unless,
              is_predicate: var_name.end_with?("?")
            }
          end

          # Check for ternary operators
          if line =~ /<%=?\s*(\w+\??)\s*\?\s*[^:]+:[^%]+%>/
            var_name = $1
            next if %w[true false nil].include?(var_name)
            conditionals << {
              name: var_name,
              line: line_num,
              type: :ternary,
              is_predicate: var_name.end_with?("?")
            }
          end

          # Check for if/unless modifiers
          if line =~ /<%=?\s*.+\s+if\s+(\w+\??)\s*%>/
            var_name = $1
            conditionals << {
              name: var_name,
              line: line_num,
              type: :if_modifier,
              is_predicate: var_name.end_with?("?")
            }
          end

          if line =~ /<%=?\s*.+\s+unless\s+(\w+\??)\s*%>/
            var_name = $1
            conditionals << {
              name: var_name,
              line: line_num,
              type: :unless_modifier,
              is_predicate: var_name.end_with?("?")
            }
          end
        end

        # Remove duplicates (same variable may appear multiple times)
        conditionals.uniq { |c| c[:name] }
      end

      # :nocov:
      def generate_covering_presets(conditionals, existing_vars)
        return [] if conditionals.empty? # defensive check, caller guarantees non-empty

        conditional_vars = conditionals.map { |c| c[:name] }.uniq
        presets = []

        # Generate presets for each combination needed to cover all branches
        # For N boolean conditionals, we need at most N+1 presets to cover all branches
        # But we try to be smart and minimize the number of presets

        if conditional_vars.size == 1
          # Single conditional: need true and false presets
          var = conditionals.first
          presets << build_preset("#{friendly_name(var[:name])} enabled", {var[:name] => true}, existing_vars)
          presets << build_preset("#{friendly_name(var[:name])} disabled", {var[:name] => false}, existing_vars)
        else
          # Multiple conditionals: generate combinations that cover all branches
          # Start with "all true" and "all false" presets
          all_true = conditional_vars.map { |v| [v, true] }.to_h
          all_false = conditional_vars.map { |v| [v, false] }.to_h

          presets << build_preset("All features enabled", all_true, existing_vars)
          presets << build_preset("All features disabled", all_false, existing_vars)

          # Add individual presets for each conditional to ensure coverage
          conditional_vars.each do |var_name|
            # Create a preset where only this variable is true
            single_true = conditional_vars.map { |v| [v, v == var_name] }.to_h
            presets << build_preset("Only #{friendly_name(var_name)}", single_true, existing_vars)
          end
        end

        presets.uniq { |p| p[:vars].to_json }
      end

      def build_preset(name, boolean_vars, existing_vars)
        vars = {}

        # Include all existing vars with default values
        existing_vars.each do |var_name, config|
          cfg = config.respond_to?(:to_unsafe_h) ? config.to_unsafe_h : (config || {})
          var_type = cfg["type"] || cfg[:type] || "String"
          var_value = cfg["value"] || cfg[:value] || ""

          vars[var_name.to_s] = {
            "type" => var_type,
            "value" => var_value
          }
        end

        # Override with boolean values for conditionals
        boolean_vars.each do |var_name, value|
          vars[var_name.to_s] = {
            "type" => "Boolean",
            "value" => value.to_s
          }
        end

        {
          name: name,
          vars: vars
        }
      end

      def friendly_name(var_name)
        # Convert variable names like "premium_user?" to "Premium user"
        var_name.to_s
          .delete_suffix("?")
          .gsub("_", " ")
          .capitalize
      end
      # :nocov:
    end
  end
end
