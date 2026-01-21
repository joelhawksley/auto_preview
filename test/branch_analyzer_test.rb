# frozen_string_literal: true

require "test_helper"

class BranchAnalyzerTest < Minitest::Test
  include TestHelper

  def setup
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@temp_dir)
  end

  def create_temp_ruby_file(content)
    path = File.join(@temp_dir, "test.rb")
    File.write(path, content)
    path
  end

  def test_analyzes_if_statement
    code = <<~RUBY
      if condition
        puts "true"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_equal 1, analyzer.branches.length
    assert_equal :if, analyzer.branches.first[:type]
    assert_includes analyzer.conditional_variables, "condition"
  end

  def test_analyzes_unless_statement
    code = <<~RUBY
      unless disabled
        puts "enabled"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_equal 1, analyzer.branches.length
    assert_equal :unless, analyzer.branches.first[:type]
    assert_includes analyzer.conditional_variables, "disabled"
  end

  def test_analyzes_case_statement
    code = <<~RUBY
      case status
      when :active
        puts "active"
      when :inactive
        puts "inactive"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_equal 1, analyzer.branches.length
    assert_equal :case, analyzer.branches.first[:type]
    assert_includes analyzer.conditional_variables, "status"
  end

  def test_analyzes_chained_method_call
    code = <<~RUBY
      if user.active?
        puts "active"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_includes analyzer.conditional_variables, "user.active?"
  end

  def test_analyzes_standalone_method_call
    code = <<~RUBY
      if admin?
        puts "admin"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_includes analyzer.conditional_variables, "admin?"
  end

  def test_analyzes_local_variable
    code = <<~RUBY
      if show_header
        puts "header"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_includes analyzer.conditional_variables, "show_header"
  end

  def test_analyzes_instance_variable
    code = <<~RUBY
      if @current_user
        puts "logged in"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_includes analyzer.conditional_variables, "@current_user"
  end

  def test_analyzes_global_variable
    code = <<~RUBY
      if $debug
        puts "debug mode"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_includes analyzer.conditional_variables, "$debug"
  end

  def test_analyzes_constant
    code = <<~RUBY
      if DEBUG
        puts "debug"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert_includes analyzer.conditional_variables, "DEBUG"
  end

  def test_analyzes_constant_path
    code = <<~RUBY
      if Rails::Application::CONSTANT
        puts "constant"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("Rails") }
  end

  def test_analyzes_and_operator
    code = <<~RUBY
      if logged_in && admin
        puts "admin"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert_includes vars, "logged_in"
    assert_includes vars, "admin"
  end

  def test_analyzes_or_operator
    code = <<~RUBY
      if owner || editor
        puts "can edit"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert_includes vars, "owner"
    assert_includes vars, "editor"
  end

  def test_analyzes_parenthesized_expression
    code = <<~RUBY
      if (a && b)
        puts "both"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert_includes vars, "a"
    assert_includes vars, "b"
  end

  def test_analyzes_method_with_arguments
    code = <<~RUBY
      if has_permission?(resource)
        puts "allowed"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert_includes vars, "has_permission?"
    assert_includes vars, "resource"
  end

  def test_generate_permutations_empty
    code = <<~RUBY
      puts "no conditions"
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    perms = analyzer.generate_permutations
    assert_equal [{}], perms
  end

  def test_generate_permutations_single_variable
    code = <<~RUBY
      if active
        puts "active"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    perms = analyzer.generate_permutations
    assert_equal 2, perms.length
    assert perms.any? { |p| p["active"] == true }
    assert perms.any? { |p| p["active"] == false }
  end

  def test_generate_permutations_two_variables
    code = <<~RUBY
      if a && b
        puts "both"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    perms = analyzer.generate_permutations
    assert_equal 4, perms.length
  end

  def test_analyzes_hash_access_pattern
    code = <<~RUBY
      if flash[:notice] ||= "default"
        puts "notice"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    # This tests the IndexOperatorWriteNode path
    assert analyzer.branches.length >= 0  # Just ensure no errors
  end

  def test_deeply_nested_chain
    code = <<~RUBY
      if user.profile.settings.enabled?
        puts "enabled"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("user") && v.include?("enabled") }
  end

  def test_statements_node_inside_parentheses
    code = <<~RUBY
      if (x = 1; y = 2; x && y)
        puts "both"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    # Tests StatementsNode path
    assert analyzer.branches.length >= 1
  end

  def test_index_operator_write_in_condition
    code = <<~RUBY
      if (flash[:notice] ||= "default")
        puts "has notice"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("flash") }
  end

  def test_call_operator_write_in_condition
    code = <<~RUBY
      if (obj.value ||= "default")
        puts "has value"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    # Tests CallOperatorWriteNode handling
    assert analyzer.branches.length >= 1
  end

  def test_collect_call_chain_with_instance_variable
    code = <<~RUBY
      if @user.active?
        puts "active"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("@user") }
  end

  def test_collect_call_chain_with_constant
    code = <<~RUBY
      if User.admin?
        puts "admin"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("User") }
  end

  def test_collect_call_chain_with_constant_path
    code = <<~RUBY
      if Admin::User.active?
        puts "active"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("Admin") }
  end

  def test_extract_receiver_name_with_chained_call
    code = <<~RUBY
      if foo.bar.baz
        puts "chained"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("foo") }
  end

  def test_extract_receiver_name_with_instance_variable
    code = <<~RUBY
      if @obj.method
        puts "method"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("@obj") }
  end

  def test_extract_receiver_fallback
    code = <<~RUBY
      if ([1,2,3][0] ||= 99)
        puts "has value"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    # Tests the else branch in extract_receiver_name (ArrayNode falls through to else)
    assert analyzer.branches.length >= 1
    # Should extract the array literal text
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("[1") }
  end

  def test_index_write_with_local_variable_receiver
    code = <<~RUBY
      my_hash = {}
      if (my_hash[:key] ||= "value")
        puts "has key"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("my_hash") }
  end

  def test_index_write_with_instance_variable_receiver
    code = <<~RUBY
      if (@data[:key] ||= "value")
        puts "has key"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("@data") }
  end

  def test_index_write_with_chained_receiver
    code = <<~RUBY
      if (obj.settings[:key] ||= "value")
        puts "has key"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    vars = analyzer.conditional_variables
    assert vars.any? { |v| v.include?("obj") }
  end

  def test_call_or_write
    code = <<~RUBY
      if (obj.value ||= "default")
        puts "has value"
      end
    RUBY
    path = create_temp_ruby_file(code)
    analyzer = AutoPreview::BranchAnalyzer.new(path)
    analyzer.analyze
    assert analyzer.branches.length >= 1
  end
end
