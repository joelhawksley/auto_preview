# frozen_string_literal: true

require "test_helper"

class CoverageVerificationTest < Minitest::Test
  include TestHelper

  def setup
    AutoPreview.clean_compiled!
  end

  def teardown
    AutoPreview.clean_compiled!
  end

  def test_compile_creates_ruby_file
    compiled_path = AutoPreview.compile(fixture_path("simple.erb"))
    
    assert File.exist?(compiled_path)
    assert compiled_path.end_with?(".rb")
    
    content = File.read(compiled_path)
    assert_includes content, "module AutoPreview"
    assert_includes content, "CompiledTemplates"
    assert_includes content, "def self.render"
  end

  def test_verify_coverage_simple_template
    runner = AutoPreview.verify_coverage(fixture_path("simple.erb"))
    
    assert runner.results
    assert runner.line_coverage > 0
    puts runner.report
  end

  def test_verify_coverage_with_conditionals
    runner = AutoPreview.verify_coverage(fixture_path("conditionals/if_statement.erb"))
    
    assert runner.results
    assert runner.results[:branches].any?, "Should detect branches"
    assert runner.results[:permutations_run] >= 1, "Should run at least one permutation"
    puts runner.report
  end

  def test_verify_coverage_if_else
    runner = AutoPreview.verify_coverage(fixture_path("conditionals/if_else.erb"))
    
    assert runner.results
    # Should detect the if/else condition
    assert runner.results[:branches].any?
    # Should run multiple permutations to cover both branches
    assert runner.results[:permutations_run] >= 2
    puts runner.report
  end

  def test_verify_coverage_string
    erb = "<% if show %>Visible<% else %>Hidden<% end %>"
    runner = AutoPreview.verify_coverage_string(erb)
    
    assert runner.results
    assert runner.results[:branches].any?
    puts runner.report
  end

  def test_verify_coverage_ternary
    runner = AutoPreview.verify_coverage(fixture_path("conditionals/ternary.erb"))
    
    assert runner.results
    puts runner.report
  end

  def test_verify_coverage_case_when
    runner = AutoPreview.verify_coverage(fixture_path("conditionals/case_when.erb"))
    
    assert runner.results
    puts runner.report
  end

  def test_fully_covered_detection
    # A simple template with no branches should be fully covered
    erb = "<p>Hello World</p>"
    runner = AutoPreview.verify_coverage_string(erb)
    
    # No branches means 100% branch coverage by default
    assert_equal 100.0, runner.branch_coverage
    assert runner.fully_covered?
  end

  def test_branch_analyzer_extracts_variables
    compiler = AutoPreview::Compiler.new(source_path: fixture_path("conditionals/if_else.erb"))
    compiler.compile
    
    analyzer = AutoPreview::BranchAnalyzer.new(compiler.compiled_path)
    analyzer.analyze
    
    assert analyzer.branches.any?
    assert analyzer.conditional_variables.any?
  end

  def test_branch_analyzer_generates_permutations
    compiler = AutoPreview::Compiler.new(source_path: fixture_path("conditionals/if_else.erb"))
    compiler.compile
    
    analyzer = AutoPreview::BranchAnalyzer.new(compiler.compiled_path)
    analyzer.analyze
    
    perms = analyzer.generate_permutations
    assert perms.length >= 2, "Should generate at least 2 permutations for true/false"
  end

  def test_complex_template_coverage
    runner = AutoPreview.verify_coverage(fixture_path("complex.erb"))
    
    assert runner.results
    puts runner.report
    
    # Complex template has multiple conditionals
    assert runner.results[:branches].length > 1
  end
end
