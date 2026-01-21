# frozen_string_literal: true

require "prism"

module AutoPreview
  # Analyzes compiled Ruby code to find conditional branches using Prism AST parser
  class BranchAnalyzer
    attr_reader :compiled_path, :branches

    def initialize(compiled_path)
      @compiled_path = compiled_path
      @branches = []
    end

    def analyze
      source = File.read(compiled_path)
      result = Prism.parse(source)
      @branches = []
      visit_node(result.value)
      self
    end

    # Returns the variables/methods involved in conditionals
    def conditional_variables
      @branches.flat_map { |b| b[:variables] }.uniq
    end

    # Generates all permutations of truthy/falsy values for branch coverage
    def generate_permutations
      vars = conditional_variables
      return [{}] if vars.empty?

      # Generate all combinations of true/false for each variable
      values = [true, false]
      combinations = values.product(*([values] * (vars.length - 1)))

      combinations.map do |combo|
        vars.zip(combo).to_h
      end
    end

    private

    def visit_node(node)
      return unless node

      case node
      when Prism::IfNode, Prism::UnlessNode
        extract_conditional(node)
      when Prism::CaseNode
        extract_case(node)
      end

      # Visit child nodes
      node.compact_child_nodes.each { |child| visit_node(child) }
    end

    def extract_conditional(node)
      predicate = node.predicate
      return unless predicate

      condition_source = predicate.location.slice
      vars = extract_variables_from_node(predicate)
      
      type = node.is_a?(Prism::IfNode) ? :if : :unless
      @branches << { type: type, condition: condition_source, variables: vars }
    end

    def extract_case(node)
      predicate = node.predicate
      return unless predicate

      condition_source = predicate.location.slice
      vars = extract_variables_from_node(predicate)
      
      @branches << { type: :case, condition: condition_source, variables: vars }
    end

    def extract_variables_from_node(node)
      vars = []
      collect_variables(node, vars, [])
      vars.uniq
    end

    def collect_variables(node, vars, chain)
      return unless node

      case node
      when Prism::CallNode
        # Method call - could be standalone (admin?) or chained (user.active?)
        receiver = node.receiver
        method_name = node.name.to_s

        if receiver
          # Chained call like user.active? or issue.pull_request?
          receiver_chain = []
          collect_call_chain(receiver, receiver_chain)
          full_chain = receiver_chain + [method_name]
          vars << full_chain.join(".")
        else
          # Standalone method call like admin? or logged_in?
          vars << method_name
        end

        # Also visit arguments for nested conditionals
        node.arguments&.arguments&.each { |arg| collect_variables(arg, vars, []) }

      when Prism::LocalVariableReadNode
        vars << node.name.to_s

      when Prism::InstanceVariableReadNode
        vars << node.name.to_s

      when Prism::GlobalVariableReadNode
        vars << node.name.to_s

      when Prism::ConstantReadNode, Prism::ConstantPathNode
        vars << node.location.slice

      when Prism::IndexOperatorWriteNode, Prism::CallOperatorWriteNode, Prism::IndexOrWriteNode, Prism::CallOrWriteNode
        # Handle hash/array access like flash[:notice] ||= "default" or arr[0] ||= val
        if node.respond_to?(:receiver) && node.receiver
          receiver_name = extract_receiver_name(node.receiver)
          if node.respond_to?(:arguments) && node.arguments
            key = node.arguments.arguments.first
            if key.is_a?(Prism::SymbolNode)
              vars << "#{receiver_name}[:#{key.value}]"
            else
              # Non-symbol key (integer, string, etc.)
              vars << "#{receiver_name}[#{key.location.slice}]"
            end
          else
            vars << receiver_name
          end
        end

      when Prism::AndNode, Prism::OrNode
        # For && and || operators, visit both sides
        collect_variables(node.left, vars, chain)
        collect_variables(node.right, vars, chain)

      when Prism::ParenthesesNode
        # For parentheses, visit the inner expression
        if node.respond_to?(:body)
          collect_variables(node.body, vars, chain)
        end

      when Prism::StatementsNode
        node.body.each { |stmt| collect_variables(stmt, vars, chain) }
      end
    end

    def collect_call_chain(node, chain)
      case node
      when Prism::CallNode
        if node.receiver
          collect_call_chain(node.receiver, chain)
        end
        chain << node.name.to_s
      when Prism::LocalVariableReadNode
        chain << node.name.to_s
      when Prism::InstanceVariableReadNode
        chain << node.name.to_s
      when Prism::ConstantReadNode
        chain << node.name.to_s
      when Prism::ConstantPathNode
        chain << node.location.slice
      end
    end

    def extract_receiver_name(node)
      case node
      when Prism::LocalVariableReadNode
        node.name.to_s
      when Prism::InstanceVariableReadNode
        node.name.to_s
      when Prism::CallNode
        if node.receiver
          "#{extract_receiver_name(node.receiver)}.#{node.name}"
        else
          node.name.to_s
        end
      else
        node.location.slice
      end
    end
  end
end
