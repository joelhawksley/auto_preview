# frozen_string_literal: true

require "json"
require "open3"

module AutoPreview
  # Runs templates with coverage tracking to verify all branches are hit
  # Uses a subprocess to avoid conflicts with existing coverage sessions
  class CoverageRunner
    attr_reader :compiler, :analyzer, :erb_analyzer, :results

    def initialize(compiler)
      @compiler = compiler
      @analyzer = BranchAnalyzer.new(compiler.compiled_path)
      @erb_analyzer = ErbAnalyzer.new(compiler.erb_source)
      @results = nil
    end

    def run
      analyzer.analyze
      erb_analyzer.analyze
      
      # Get case statement values from Herb parser
      case_values = erb_analyzer.case_values
      
      # Get block variable conditions (e.g., product.in_stock? inside @products.each)
      block_conditions = erb_analyzer.block_variable_conditions
      
      # Get string comparisons (e.g., action_name == "files")
      string_comparisons = erb_analyzer.string_comparisons
      
      # Generate permutations, using specific values for case statements and block conditions
      permutations = generate_permutations_with_case_values(case_values, block_conditions, string_comparisons)

      # Run coverage in a subprocess to avoid conflicts
      coverage_data = run_in_subprocess(permutations, block_conditions)

      @results = {
        compiled_path: compiler.compiled_path,
        source_path: compiler.source_path,
        permutations_run: permutations.length,
        outputs: coverage_data[:outputs],
        coverage: coverage_data[:coverage],
        branches: analyzer.branches,
        case_values: case_values,
        block_conditions: block_conditions,
        string_comparisons: string_comparisons
      }

      self
    end
    
    private
    
    def generate_permutations_with_case_values(case_values, block_conditions = [], string_comparisons = {})
      # Collect block variable conditions to exclude from top-level boolean vars
      block_var_patterns = block_conditions.flat_map do |bc|
        bc[:conditions].map { |c| "#{bc[:block_var]}.#{c}" }
      end
      
      # Get computed variables that should not be mocked
      # (we want their computation to run for branch coverage)
      computed = erb_analyzer.computed_variables
      
      # Get dependencies of computed variables - these SHOULD be mocked
      # to influence the computed values
      computed_deps = erb_analyzer.computed_variable_dependencies
      dependency_vars = computed_deps.values.flatten.uniq
      
      # Get boolean variables, excluding:
      # - case variables (handled separately with their when values)
      # - block variable conditions  
      # - computed variables (we want their computation to run)
      # - string comparison variables (handled separately with specific values)
      bool_vars = analyzer.conditional_variables.reject do |v| 
        case_values.key?(v) || block_var_patterns.include?(v) || computed.include?(v) || string_comparisons.key?(v)
      end
      
      # Add dependency vars that aren't already in bool_vars (and aren't string comparisons)
      dependency_vars.each do |dep|
        bool_vars << dep unless bool_vars.include?(dep) || string_comparisons.key?(dep)
      end
      
      # Always use minimal branch coverage approach - just need each branch true/false once
      generate_minimal_branch_coverage(bool_vars, case_values, block_conditions, string_comparisons)
    end
    
    def generate_minimal_branch_coverage(bool_vars, case_values, block_conditions, string_comparisons = {})
      # Strategy for minimal branch coverage:
      # 1. Base permutation with all true - hits all "then" branches
      # 2. Base permutation with all false - hits all "else" branches  
      # 3. For nested conditionals, we need permutations where outer guards pass
      #    but inner conditions vary. We approximate this by adding permutations
      #    where each variable is flipped individually from base_true.
      
      permutations = []
      
      # Base permutation with all true (except guard-breakers like hide_actions)
      base_true = {}
      bool_vars.each do |v|
        # For negative guards (hide_actions, etc.), use false to allow entering blocks
        if v.to_s.start_with?("hide_") || v.to_s.include?("_blocked")
          base_true[v] = false
        else
          base_true[v] = true
        end
      end
      case_values.each { |var, values| base_true[var] = values.first if values.any? }
      # For string comparisons, use the first expected value to make comparisons pass
      string_comparisons.each { |var, values| base_true[var] = values.first if values.any? }
      block_conditions.each do |bc|
        bc[:conditions].each do |c|
          base_true["#{bc[:iterator]}.__block_item__.#{c}"] = true
        end
      end
      permutations << base_true
      
      # Base permutation with all false  
      base_false = {}
      bool_vars.each { |v| base_false[v] = false }
      case_values.each { |var, values| base_false[var] = "__unmatched__" }
      # For string comparisons, use an unmatched value to make comparisons fail
      string_comparisons.each { |var, _| base_false[var] = "__no_match__" }
      block_conditions.each do |bc|
        bc[:conditions].each do |c|
          base_false["#{bc[:iterator]}.__block_item__.#{c}"] = false
        end
      end
      permutations << base_false
      
      # For each boolean variable, add a permutation where only that variable differs
      # from base_true. This helps cover the "else" branch of each conditional
      # while keeping outer guards passing.
      bool_vars.each do |v|
        perm = base_true.dup
        # Flip this variable
        perm[v] = !base_true[v]
        permutations << perm unless permutations.include?(perm)
      end
      
      # For case statements, add one permutation per additional value
      case_values.each do |var, values|
        values[1..-1]&.each do |val|
          perm = base_true.dup
          perm[var] = val
          permutations << perm
        end
      end
      
      # For string comparisons, add one permutation per each distinct value
      string_comparisons.each do |var, values|
        values.each do |val|
          perm = base_true.dup
          perm[var] = val
          permutations << perm unless permutations.include?(perm)
        end
      end
      
      # For block conditions, flip each individually
      block_conditions.each do |bc|
        bc[:conditions].each do |c|
          key = "#{bc[:iterator]}.__block_item__.#{c}"
          perm = base_true.dup
          perm[key] = false
          permutations << perm unless permutations.include?(perm)
        end
      end
      
      # Add pairwise combinations for nested conditional coverage
      add_pairwise_permutations(permutations, bool_vars, base_true)
      
      permutations.uniq
    end
    
    def add_pairwise_permutations(permutations, bool_vars, base_true)
      # For better coverage of nested conditionals and computed variables,
      # add permutations with pairs of variables flipped.
      # This is especially useful when:
      # - An outer guard (A) must pass for an inner conditional (B) to run
      # - A computed variable depends on multiple inputs (A && B)
      
      # Limit to reasonable number of pairs to avoid explosion
      vars_to_pair = bool_vars.first(20)
      
      vars_to_pair.each_with_index do |v1, i|
        vars_to_pair[(i+1)..-1].each do |v2|
          # Skip if both are guard-type variables
          next if (v1.to_s.start_with?("hide_") || v1.to_s.include?("_blocked")) &&
                  (v2.to_s.start_with?("hide_") || v2.to_s.include?("_blocked"))
          
          # Create permutation with both flipped
          perm = base_true.dup
          perm[v1] = !base_true[v1]
          perm[v2] = !base_true[v2]
          permutations << perm unless permutations.include?(perm)
        end
      end
      
      # Add some triple combinations for complex nested conditionals
      vars_to_triple = bool_vars.first(10)
      vars_to_triple.each_with_index do |v1, i|
        vars_to_triple[(i+1)..-1].each_with_index do |v2, j|
          vars_to_triple[(i+j+2)..-1].each do |v3|
            perm = base_true.dup
            perm[v1] = !base_true[v1]
            perm[v2] = !base_true[v2]
            perm[v3] = !base_true[v3]
            permutations << perm unless permutations.include?(perm)
          end
        end
      end
    end
    
    public

    def fully_covered?
      return false unless results

      results[:coverage][:branch_coverage] == 100.0
    end

    def line_coverage
      results&.dig(:coverage, :line_coverage) || 0.0
    end

    def branch_coverage
      results&.dig(:coverage, :branch_coverage) || 0.0
    end

    def uncovered_lines
      results&.dig(:coverage, :uncovered_lines) || []
    end

    def uncovered_branches
      results&.dig(:coverage, :uncovered_branches) || []
    end

    def report
      return "No results yet. Run #run first." unless results

      lines = []
      lines << "=" * 60
      lines << "AutoPreview Coverage Report"
      lines << "=" * 60
      lines << ""
      lines << "Source: #{compiler.source_path || '(string)'}"
      lines << "Compiled: #{compiler.compiled_path}"
      lines << ""
      lines << "Branches found: #{results[:branches].length}"
      lines << "Permutations run: #{results[:permutations_run]}"
      lines << ""
      lines << "Coverage Results:"
      lines << "  Line Coverage:   #{results[:coverage][:line_coverage].round(1)}%"
      lines << "  Branch Coverage: #{results[:coverage][:branch_coverage].round(1)}%"
      lines << ""

      if uncovered_lines.any?
        lines << "Uncovered Lines: #{uncovered_lines.join(', ')}"
      end

      if uncovered_branches.any?
        lines << "Uncovered Branches:"
        uncovered_branches.each do |branch|
          lines << "  - Line #{branch[:line]}: #{branch[:type]} (#{branch[:id]})"
        end
      end

      lines << ""
      if fully_covered?
        lines << "✅ All branches covered!"
      else
        lines << "❌ Some branches not covered"
      end
      lines << ""

      lines.join("\n")
    end

    private

    def run_in_subprocess(permutations, block_conditions = [])
      # Create a Ruby script to run coverage
      script = generate_coverage_script(permutations, block_conditions)
      script_path = "#{compiler.compiled_path}.runner.rb"
      File.write(script_path, script)

      begin
        # Run the script in a subprocess
        stdout, stderr, status = Open3.capture3("ruby", script_path)

        if status.success?
          JSON.parse(stdout, symbolize_names: true)
        else
          {
            outputs: [{ error: stderr, success: false }],
            coverage: default_coverage
          }
        end
      ensure
        File.delete(script_path) if File.exist?(script_path)
      end
    end

    def generate_coverage_script(permutations, block_conditions = [])
      lib_path = File.expand_path("../..", __FILE__)  # Points to lib/ directory
      permutations_json = JSON.generate(permutations)
      block_conditions_json = JSON.generate(block_conditions.map { |bc| { iterator: bc[:iterator], conditions: bc[:conditions] } })

      <<~RUBY
        require "coverage"
        require "json"

        # Start coverage before loading the template
        Coverage.start(lines: true, branches: true)

        # Add lib to load path
        $LOAD_PATH.unshift(#{lib_path.inspect})
        require "auto_preview"

        # Load the compiled template
        load #{compiler.compiled_path.inspect}

        def build_nested_mock(method_chain, final_value)
          return final_value if method_chain.empty?

          obj = Object.new
          current_method = method_chain.first.to_sym
          remaining = method_chain[1..]

          if remaining.empty?
            obj.define_singleton_method(current_method) { final_value }
          else
            nested = build_nested_mock(remaining, final_value)
            obj.define_singleton_method(current_method) { nested }
          end

          obj.define_singleton_method(:method_missing) { |name, *args, &block| AutoPreview::MockContext::MockValue.new(name) }
          obj.define_singleton_method(:respond_to_missing?) { |*| true }

          obj
        end

        def build_hash_mock(key, value)
          # Creates a mock object that responds to [] with the given key returning value
          hash_obj = Object.new
          captured_key = key.to_sym
          captured_value = value

          hash_obj.define_singleton_method(:[]) do |k|
            if k == captured_key
              captured_value
            else
              AutoPreview::MockContext::MockValue.new("hash[\#{k}]")
            end
          end

          hash_obj.define_singleton_method(:method_missing) { |name, *args, &block| AutoPreview::MockContext::MockValue.new(name) }
          hash_obj.define_singleton_method(:respond_to_missing?) { |*| true }

          hash_obj
        end

        def build_iterator_mock(conditions_hash)
          # Creates a mock object that yields items with configured method responses
          # conditions_hash is like { "in_stock?" => true }
          
          item = Object.new
          conditions_hash.each do |method_name, return_value|
            item.define_singleton_method(method_name.to_sym) { return_value }
          end
          
          # Add method_missing for other methods
          item.define_singleton_method(:method_missing) { |name, *args, &block| AutoPreview::MockContext::MockValue.new(name) }
          item.define_singleton_method(:respond_to_missing?) { |*| true }
          
          # Create the iterator that yields this item
          iterator = Object.new
          captured_item = item
          iterator.define_singleton_method(:each) do |&block|
            block.call(captured_item) if block
            iterator
          end
          iterator.define_singleton_method(:map) do |&block|
            block ? [block.call(captured_item)] : [captured_item].to_enum(:map)
          end
          iterator.define_singleton_method(:method_missing) { |name, *args, &block| AutoPreview::MockContext::MockValue.new(name) }
          iterator.define_singleton_method(:respond_to_missing?) { |*| true }
          
          iterator
        end

        block_conditions = JSON.parse(#{block_conditions_json.inspect})
        permutations = JSON.parse(#{permutations_json.inspect})
        outputs = []

        permutations.each do |perm|
          mock_values = {}
          block_item_configs = {}  # iterator => { method => value }
          
          # Sort permutation keys by number of dots (descending) - deeper paths first
          # This processes issue.pull_request.open? before issue.pull_request before issue
          sorted_vars = perm.keys.sort_by { |k| -k.to_s.count(".") }
          
          sorted_vars.each do |var|
            value = perm[var]
            var_clean = var.to_s
            
            # Check for block item pattern like "@products.__block_item__.in_stock?"
            if var_clean =~ /^(@?[a-zA-Z_][a-zA-Z0-9_]*)\\.__block_item__\\.([a-zA-Z_][a-zA-Z0-9_]*\\??)$/
              iterator_name = Regexp.last_match(1)
              method_name = Regexp.last_match(2)
              block_item_configs[iterator_name] ||= {}
              block_item_configs[iterator_name][method_name] = value
            # Check for hash access pattern like "flash[:notice]"
            elsif var_clean =~ /^([a-zA-Z_@][a-zA-Z0-9_]*)\\[:([a-zA-Z_][a-zA-Z0-9_]*)\\]$/
              hash_name = Regexp.last_match(1).to_sym
              hash_key = Regexp.last_match(2)
              # Merge into existing hash mock if present, otherwise create new
              if mock_values[hash_name]
                # Already have a mock for this hash, add this key to it
                existing = mock_values[hash_name]
                existing_get = existing.method(:[])
                captured_key = hash_key.to_sym
                captured_value = value
                existing.define_singleton_method(:[]) do |k|
                  if k == captured_key
                    captured_value
                  else
                    existing_get.call(k)
                  end
                end
              else
                mock_values[hash_name] = build_hash_mock(hash_key, value)
              end
            elsif var_clean.include?(".")
              # Nested like "user.returning?" - build mock object or add to existing
              parts = var_clean.split(".")
              root = parts.first.to_sym
              method_name = parts[1].to_sym
              
              if mock_values[root]
                # Check if this SPECIFIC method was explicitly defined (not just via method_missing)
                # by checking if it's a singleton method (explicitly defined) vs inherited/method_missing
                explicitly_defined = mock_values[root].singleton_methods.include?(method_name)
                
                if explicitly_defined
                  # Check if this method returns a mock object (from a deeper chain)
                  # e.g., don't overwrite issue.pull_request if issue.pull_request.open? was already set
                  existing_value = mock_values[root].public_send(method_name) rescue nil
                  
                  if existing_value.is_a?(Object) && existing_value.respond_to?(:method_missing) && 
                     existing_value.class != TrueClass && existing_value.class != FalseClass &&
                     existing_value.class != AutoPreview::MockContext::MockValue
                    # Already have a nested mock object for this method - don't overwrite
                    # This keeps issue.pull_request as a mock object that can respond to .open?
                  else
                    # Overwrite the existing simple value with new value
                    captured_val = value
                    mock_values[root].define_singleton_method(method_name) { |*args| captured_val }
                  end
                else
                  # Method not explicitly defined yet, add it
                  captured_val = value
                  mock_values[root].define_singleton_method(method_name) { |*args| captured_val }
                end
              else
                # Create new mock with this method
                mock_values[root] = build_nested_mock(parts[1..], value)
              end
            else
              # Simple variable like "logged_in" or "logged_in?"
              if mock_values.key?(var_clean.to_sym)
                # Already have a mock from nested processing
                if value == false
                  # For false, replace with falsy value. This breaks nested method calls
                  # but if the variable is false, those calls shouldn't be reached anyway.
                  mock_values[var_clean.to_sym] = value
                end
                # For true, keep existing mock (it's already truthy)
              elsif value == true
                # Use MockValue for true values so they can respond to method calls
                mock_values[var_clean.to_sym] = AutoPreview::MockContext::MockValue.new(var_clean)
              else
                mock_values[var_clean.to_sym] = value
              end
            end
          end
          
          # Build iterator mocks for block conditions
          block_item_configs.each do |iterator_name, conditions|
            key = iterator_name.start_with?("@") ? iterator_name.to_sym : iterator_name.to_sym
            mock_values[key] = build_iterator_mock(conditions)
          end

          context = AutoPreview::MockContext.new(mock_values: mock_values)
          begin
            output = AutoPreview::CompiledTemplates::#{compiler.class_name}.render(context)
            outputs << { permutation: perm, output: output, success: true }
          rescue => e
            outputs << { permutation: perm, error: e.message, backtrace: e.backtrace.first(5), success: false }
          end
        end

        # Get coverage results
        coverage_data = Coverage.result
        file_coverage = coverage_data[#{compiler.compiled_path.inspect}]

        def analyze_coverage(file_coverage)
          return default_coverage unless file_coverage

          lines = file_coverage[:lines] || []
          branches = file_coverage[:branches] || {}

          executable_lines = lines.each_with_index.select { |count, _| !count.nil? }
          covered_lines = executable_lines.select { |count, _| count && count > 0 }
          uncovered = executable_lines.select { |count, _| count == 0 }.map { |_, idx| idx + 1 }

          line_pct = executable_lines.empty? ? 100.0 : (covered_lines.length.to_f / executable_lines.length * 100)

          total_branches = 0
          covered_branches = 0
          uncovered_branch_info = []

          branches.each do |location, branch_data|
            branch_data.each do |branch_id, count|
              total_branches += 1
              if count && count > 0
                covered_branches += 1
              else
                uncovered_branch_info << {
                  line: location[2],
                  type: branch_id[0],
                  id: branch_id[1]
                }
              end
            end
          end

          branch_pct = total_branches.zero? ? 100.0 : (covered_branches.to_f / total_branches * 100)

          {
            line_coverage: line_pct,
            branch_coverage: branch_pct,
            lines_total: executable_lines.length,
            lines_covered: covered_lines.length,
            branches_total: total_branches,
            branches_covered: covered_branches,
            uncovered_lines: uncovered,
            uncovered_branches: uncovered_branch_info
          }
        end

        def default_coverage
          {
            line_coverage: 0.0,
            branch_coverage: 0.0,
            lines_total: 0,
            lines_covered: 0,
            branches_total: 0,
            branches_covered: 0,
            uncovered_lines: [],
            uncovered_branches: []
          }
        end

        result = {
          outputs: outputs,
          coverage: analyze_coverage(file_coverage)
        }

        puts JSON.generate(result)
      RUBY
    end

    def default_coverage
      {
        line_coverage: 0.0,
        branch_coverage: 0.0,
        lines_total: 0,
        lines_covered: 0,
        branches_total: 0,
        branches_covered: 0,
        uncovered_lines: [],
        uncovered_branches: []
      }
    end
  end
end
