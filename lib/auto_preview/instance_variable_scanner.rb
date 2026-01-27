# frozen_string_literal: true

require "herb"

module AutoPreview
  # Scans ERB templates using Herb's AST to detect instance variables.
  # Uses Prism to parse the Ruby code within ERB tags for accurate detection.
  class InstanceVariableScanner
    def self.scan(template_source)
      new.scan(template_source)
    end

    def scan(template_source)
      result = Herb.parse(template_source)
      # :nocov: - Herb always returns a value
      return [] unless result.value
      # :nocov:

      instance_vars = Set.new
      collect_instance_variables(result.value, instance_vars)
      instance_vars.to_a
    end

    private

    def collect_instance_variables(node, vars)
      # Handle ERB content nodes (regular ERB output tags)
      if node.is_a?(Herb::AST::ERBContentNode)
        extract_ivars_from_erb(node, vars)
      end

      # Handle ERB control flow nodes (if, unless, each, etc.)
      # These have a 'content' attribute with the Ruby condition/expression
      if node.respond_to?(:content) && !node.is_a?(Herb::AST::ERBContentNode)
        extract_ivars_from_content(node.content, vars)
      end

      # Handle statements inside ERB control flow nodes
      if node.respond_to?(:statements) && node.statements
        node.statements.each { |child| collect_instance_variables(child, vars) }
      end

      # Handle subsequent (else/elsif) branches
      if node.respond_to?(:subsequent) && node.subsequent
        collect_instance_variables(node.subsequent, vars)
      end

      # Recursively process children
      if node.respond_to?(:children) && node.children
        node.children.each { |child| collect_instance_variables(child, vars) }
      end

      if node.respond_to?(:body) && node.body
        node.body.each { |child| collect_instance_variables(child, vars) }
      end
    end

    def extract_ivars_from_content(content, vars)
      ruby_code = content.respond_to?(:value) ? content.value : content.to_s
      return if ruby_code.nil? || ruby_code.strip.empty?

      parse_result = Prism.parse(ruby_code)
      find_instance_variables(parse_result.value, vars)
    rescue StandardError
      # :nocov:
      ruby_code.scan(/@[a-zA-Z_]\w*/).each { |ivar| vars << ivar }
      # :nocov:
    end

    def extract_ivars_from_erb(node, vars)
      # Get the Ruby code content from the ERB tag
      content = node.content
      # :nocov: - Herb content always has .value
      ruby_code = content.respond_to?(:value) ? content.value : content.to_s
      # :nocov:
      return if ruby_code.nil? || ruby_code.strip.empty?

      # Use Prism to parse the Ruby code and find instance variables
      # Prism handles incomplete code gracefully and still produces an AST
      parse_result = Prism.parse(ruby_code)
      find_instance_variables(parse_result.value, vars)
    rescue StandardError
      # :nocov:
      # Fallback to regex if Prism parsing completely fails
      ruby_code.scan(/@[a-zA-Z_]\w*/).each { |ivar| vars << ivar }
      # :nocov:
    end

    def find_instance_variables(node, vars)
      # :nocov: - Prism always returns a value
      return unless node
      # :nocov:

      # Check if this node is an instance variable read
      if node.is_a?(Prism::InstanceVariableReadNode)
        vars << node.name.to_s
      end

      # Check if this node is an instance variable write
      if node.is_a?(Prism::InstanceVariableWriteNode)
        vars << node.name.to_s
      end

      # Check if this node is an instance variable and method
      if node.is_a?(Prism::InstanceVariableAndWriteNode)
        vars << node.name.to_s
      end

      # Check if this node is an instance variable or method
      if node.is_a?(Prism::InstanceVariableOrWriteNode)
        vars << node.name.to_s
      end

      # Check if this node is an instance variable operator write
      if node.is_a?(Prism::InstanceVariableOperatorWriteNode)
        vars << node.name.to_s
      end

      # Check if this node is an instance variable target (for assignment)
      if node.is_a?(Prism::InstanceVariableTargetNode)
        vars << node.name.to_s
      end

      # Recursively check all child nodes
      node.child_nodes.compact.each do |child|
        find_instance_variables(child, vars)
      end
    end
  end
end
