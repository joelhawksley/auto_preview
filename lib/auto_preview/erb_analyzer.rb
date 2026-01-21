# frozen_string_literal: true

require "herb"
require "prism"

module AutoPreview
  # Analyzes ERB source using Herb parser to extract case/when values
  # and other conditional structures
  class ErbAnalyzer
    attr_reader :erb_source, :case_statements, :block_conditionals

    def initialize(erb_source)
      @erb_source = erb_source
      @case_statements = []
      @block_conditionals = []  # Tracks conditionals inside blocks like each
    end

    def analyze
      result = Herb.parse(erb_source)
      return self unless result.value

      find_nodes(result.value)
      self
    end

    # Returns hash mapping case variables to their possible when values
    def case_values
      @case_statements.to_h do |case_stmt|
        [case_stmt[:variable], case_stmt[:when_values]]
      end
    end

    # Returns info about conditionals that use block variables
    # e.g., { iterator: "@products", block_var: "product", conditions: ["in_stock?"] }
    def block_variable_conditions
      @block_conditionals
    end
    
    # Identifies computed variables - those derived from other variables
    # These should NOT be mocked because we want their computation to run for branch coverage
    # Returns array of variable names
    def computed_variables
      computed = []
      
      # Parse the ERB to find Ruby code blocks
      result = Herb.parse(erb_source)
      return computed unless result.value
      
      # Collect all ERB content nodes
      erb_contents = []
      collect_erb_content(result.value, erb_contents)
      
      # Parse each Ruby code block with Prism
      erb_contents.each do |content|
        ruby_code = content.strip
        next if ruby_code.empty?
        
        begin
          prism_result = Prism.parse(ruby_code)
          find_computed_variables(prism_result.value, computed)
        rescue
          # Skip unparseable code fragments
        end
      end
      
      computed.uniq
    end

    # Extracts method calls that computed variables depend on
    # These should be added to conditional variables for permutation
    # Returns hash of { computed_var => [dependencies] }
    def computed_variable_dependencies
      deps = {}
      
      # Parse the ERB to find Ruby code blocks
      result = Herb.parse(erb_source)
      return deps unless result.value
      
      # Collect all ERB content nodes
      erb_contents = []
      collect_erb_content(result.value, erb_contents)
      
      # Parse each Ruby code block with Prism
      erb_contents.each do |content|
        ruby_code = content.strip
        next if ruby_code.empty?
        
        begin
          prism_result = Prism.parse(ruby_code)
          extract_dependencies(prism_result.value, deps)
        rescue
          # Skip unparseable code fragments
        end
      end
      
      deps
    end

    # Detects string comparisons in computed variable assignments
    # e.g., action_name == "files" -> { "action_name" => ["files", "commits", ...] }
    # Returns hash of { variable => [possible_values] }
    def string_comparisons
      comparisons = Hash.new { |h, k| h[k] = [] }
      
      # Parse the ERB to find Ruby code blocks
      result = Herb.parse(erb_source)
      return comparisons unless result.value
      
      # Collect all ERB content nodes
      erb_contents = []
      collect_erb_content(result.value, erb_contents)
      
      # Parse each Ruby code block with Prism
      erb_contents.each do |content|
        ruby_code = content.strip
        next if ruby_code.empty?
        
        begin
          prism_result = Prism.parse(ruby_code)
          extract_string_comparisons(prism_result.value, comparisons)
        rescue
          # Skip unparseable code fragments
        end
      end
      
      # Convert to regular hash and dedupe values
      comparisons.transform_values(&:uniq)
    end

    private
    
    def extract_string_comparisons(node, comparisons)
      return unless node
      
      case node
      when Prism::CallNode
        method_name = node.name.to_s
        # Check for == comparison with string literal
        if method_name == "==" && node.arguments&.arguments&.length == 1
          arg = node.arguments.arguments.first
          if arg.is_a?(Prism::StringNode)
            string_value = arg.unescaped
            # Get the variable being compared
            var_name = case node.receiver
            when Prism::LocalVariableReadNode
              node.receiver.name.to_s
            when Prism::InstanceVariableReadNode
              node.receiver.name.to_s
            when Prism::CallNode
              build_call_path(node.receiver)
            else
              nil
            end
            comparisons[var_name] << string_value if var_name
          end
        end
      end
      
      # Recurse into child nodes
      node.compact_child_nodes.each { |child| extract_string_comparisons(child, comparisons) }
    end
    
    def extract_dependencies(node, deps)
      return unless node
      
      case node
      when Prism::LocalVariableWriteNode
        # var = expr - collect method calls from the expression
        if complex_expression?(node.value)
          var_name = node.name.to_s
          method_calls = []
          collect_boolean_method_calls(node.value, method_calls)
          deps[var_name] = method_calls if method_calls.any?
        end
      end
      
      # Recurse into child nodes
      node.compact_child_nodes.each { |child| extract_dependencies(child, deps) }
    end
    
    def collect_boolean_method_calls(node, calls)
      return unless node
      
      case node
      when Prism::CallNode
        method_name = node.name.to_s
        # Collect method calls that look like boolean checks
        if method_name.end_with?("?") || method_name.include?("enabled") || 
           method_name.include?("visible") || method_name.include?("writable")
          # Build the full call path
          call_path = build_call_path(node)
          calls << call_path if call_path
        end
        # Also check receiver and arguments for nested calls
        collect_boolean_method_calls(node.receiver, calls) if node.receiver
        if node.arguments
          node.arguments.arguments.each { |arg| collect_boolean_method_calls(arg, calls) }
        end
        
      when Prism::AndNode, Prism::OrNode
        collect_boolean_method_calls(node.left, calls)
        collect_boolean_method_calls(node.right, calls)
        
      when Prism::ParenthesesNode
        collect_boolean_method_calls(node.body, calls)
        
      when Prism::StatementsNode
        node.body.each { |stmt| collect_boolean_method_calls(stmt, calls) }
        
      else
        node.compact_child_nodes.each { |child| collect_boolean_method_calls(child, calls) }
      end
    end
    
    def build_call_path(node)
      return nil unless node.is_a?(Prism::CallNode)
      
      method_name = node.name.to_s
      
      if node.receiver
        receiver_path = case node.receiver
        when Prism::CallNode
          build_call_path(node.receiver)
        when Prism::LocalVariableReadNode
          node.receiver.name.to_s
        when Prism::InstanceVariableReadNode
          node.receiver.name.to_s
        when Prism::ConstantReadNode
          node.receiver.name.to_s
        else
          nil
        end
        
        return "#{receiver_path}.#{method_name}" if receiver_path
      end
      
      # Top-level method call
      method_name
    end
    
    def collect_erb_content(node, contents)
      # Collect content from ERB execution nodes (<% ... %>)
      if node.is_a?(Herb::AST::ERBContentNode) && node.respond_to?(:content) && node.content.respond_to?(:value)
        contents << node.content.value
      elsif node.respond_to?(:content) && node.content.respond_to?(:value)
        contents << node.content.value
      end
      
      if node.respond_to?(:child_nodes)
        node.child_nodes.each { |child| collect_erb_content(child, contents) if child }
      end
    end
    
    def find_computed_variables(node, computed)
      return unless node
      
      case node
      when Prism::LocalVariableWriteNode
        # var = expr
        if complex_expression?(node.value)
          computed << node.name.to_s
        end
        
      when Prism::LocalVariableOrWriteNode
        # var ||= expr
        if complex_expression?(node.value)
          computed << node.name.to_s
        end
        
      when Prism::MultiWriteNode
        # Multiple assignment - check each target
        node.lefts.each do |target|
          if target.is_a?(Prism::LocalVariableTargetNode)
            computed << target.name.to_s
          end
        end
      end
      
      # Recurse into child nodes
      node.compact_child_nodes.each { |child| find_computed_variables(child, computed) }
    end
    
    def complex_expression?(node)
      return false unless node
      
      case node
      when Prism::CallNode
        # Method calls are complex (e.g., foo.bar, foo&.bar)
        return true if node.receiver
        # Ternary or method with arguments
        return true if node.arguments
        # Safe navigation operator
        return true if node.safe_navigation?
        false
        
      when Prism::IfNode, Prism::UnlessNode
        # Inline conditionals (x if condition, ternary)
        true
        
      when Prism::AndNode, Prism::OrNode
        # Logical operators
        true
        
      when Prism::ParenthesesNode
        # Check inside parentheses
        complex_expression?(node.body)
        
      when Prism::StatementsNode
        # Check all statements
        node.body.any? { |stmt| complex_expression?(stmt) }
        
      else
        # Recurse into child nodes to find nested complexity
        node.compact_child_nodes.any? { |child| complex_expression?(child) }
      end
    end

    def find_nodes(node)
      case node
      when Herb::AST::ERBCaseNode
        extract_case_statement(node)
      when Herb::AST::ERBBlockNode
        extract_block_conditionals(node)
        return  # Don't recurse into children, extract_block_conditionals handles it
      end

      if node.respond_to?(:child_nodes)
        node.child_nodes.each { |child| find_nodes(child) if child }
      end
    end

    def extract_block_conditionals(block_node)
      content = block_node.content.value.strip
      
      # Match patterns like "@products.each do |product|" or "items.each do |item|"
      if content =~ /(\@?[a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*)\s*\.\s*each\s+do\s*\|\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\|/
        iterator = $1
        block_var = $2
        
        block_context = { iterator: iterator, block_var: block_var, conditions: [] }
        
        # Search for conditionals inside this block that use the block variable
        find_conditionals_in_block(block_node, block_context)
        
        if block_context[:conditions].any?
          @block_conditionals << block_context
        end
      end
      
      # Still recurse to find nested structures
      if block_node.respond_to?(:child_nodes)
        block_node.child_nodes.each { |child| find_nodes(child) if child }
      end
    end

    def find_conditionals_in_block(node, block_context)
      case node
      when Herb::AST::ERBIfNode
        check_block_conditional(node, block_context)
      when Herb::AST::ERBCaseNode
        extract_case_statement(node)
      end

      if node.respond_to?(:child_nodes)
        node.child_nodes.each { |child| find_conditionals_in_block(child, block_context) if child }
      end
    end

    def check_block_conditional(if_node, block_context)
      content = if_node.content.value.strip
      block_var = block_context[:block_var]
      
      # Check if condition uses block variable, e.g., "if product.in_stock?"
      if content =~ /(?:if|unless)\s+#{Regexp.escape(block_var)}\.([a-zA-Z_][a-zA-Z0-9_]*\??)/
        method_name = $1
        block_context[:conditions] << method_name unless block_context[:conditions].include?(method_name)
      end
    end

    def extract_case_statement(case_node)
      # Extract the variable from "case variable"
      case_content = case_node.content.value.strip
      variable = case_content.sub(/\Acase\s+/, "").strip

      when_values = []
      case_node.child_nodes.each do |child|
        if child.is_a?(Herb::AST::ERBWhenNode)
          when_content = child.content.value.strip
          # Extract value from "when value" or "when value1, value2"
          value_str = when_content.sub(/\Awhen\s+/, "").strip
          # Handle multiple values separated by comma
          values = value_str.split(/\s*,\s*/)
          values.each do |val|
            # Remove quotes from string literals
            clean_val = val.strip
            if clean_val =~ /\A["'](.*)["']\z/
              when_values << $1
            elsif clean_val =~ /\A:(\w+)\z/
              # Symbol
              when_values << clean_val
            else
              # Could be a constant or other expression
              when_values << clean_val
            end
          end
        end
      end

      @case_statements << {
        variable: variable,
        when_values: when_values
      }
    end
  end
end
