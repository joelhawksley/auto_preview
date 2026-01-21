# frozen_string_literal: true

require "test_helper"

# This test ensures all ERB fixture files are rendered with various inputs
# to achieve maximum coverage of all branches
class FixturesCoverageTest < Minitest::Test
  include TestHelper

  # simple.erb - just needs to be rendered
  def test_simple_erb
    result = AutoPreview.render(fixture_path("simple.erb"))
    assert_includes result, "Hello"
  end

  # complex.erb - needs current_user true and false, in_stock true and false
  def test_complex_erb_with_logged_in_user_and_in_stock
    products = [OpenStruct.new(name: "Product", price: 10, image_url: "img.png", description: "desc", in_stock?: true)]
    current_user = OpenStruct.new(name: "User")
    result = AutoPreview.render(
      fixture_path("complex.erb"),
      locals: { :@products => products, current_user: current_user }
    )
    assert_includes result, "User"
    assert_includes result, "Logout"
    assert_includes result, "Add to Cart"
  end

  def test_complex_erb_with_logged_out_user
    products = [OpenStruct.new(name: "Product", price: 10, image_url: "img.png", description: "desc", in_stock?: true)]
    result = AutoPreview.render(
      fixture_path("complex.erb"),
      locals: { :@products => products, current_user: nil }
    )
    assert_includes result, "Login"
  end

  def test_complex_erb_with_out_of_stock
    products = [OpenStruct.new(name: "Product", price: 10, image_url: "img.png", description: "desc", in_stock?: false)]
    current_user = OpenStruct.new(name: "User")
    result = AutoPreview.render(
      fixture_path("complex.erb"),
      locals: { :@products => products, current_user: current_user }
    )
    assert_includes result, "Out of Stock"
  end

  # if_statement.erb - needs logged_in true
  def test_if_statement_erb_truthy
    result = AutoPreview.render(fixture_path("conditionals/if_statement.erb"))
    assert_includes result, "User is logged in"
  end

  # if_else.erb - needs user.returning? true and false
  def test_if_else_erb_returning_user
    user = OpenStruct.new(returning?: true, name: "Alice")
    result = AutoPreview.render(
      fixture_path("conditionals/if_else.erb"),
      locals: { user: user }
    )
    assert_includes result, "Welcome back"
    assert_includes result, "Alice"
  end

  def test_if_else_erb_new_user
    user = OpenStruct.new(returning?: false, name: "Bob")
    result = AutoPreview.render(
      fixture_path("conditionals/if_else.erb"),
      locals: { user: user }
    )
    assert_includes result, "Welcome, new visitor"
  end

  # unless_statement.erb - needs items.any? true and false
  def test_unless_statement_erb_no_items
    result = AutoPreview.render(fixture_path("conditionals/unless_statement.erb"))
    assert_includes result, "No items found"
  end

  def test_unless_statement_erb_with_items
    items = [OpenStruct.new(name: "Item 1"), OpenStruct.new(name: "Item 2")]
    result = AutoPreview.render(
      fixture_path("conditionals/unless_statement.erb"),
      locals: { items: items }
    )
    assert_includes result, "Item 1"
    assert_includes result, "Item 2"
  end

  # ternary.erb - needs admin? true and false
  def test_ternary_erb_admin
    result = AutoPreview.render(
      fixture_path("conditionals/ternary.erb"),
      locals: { admin?: true, user: OpenStruct.new(admin?: true) }
    )
    assert_includes result, "Admin Dashboard"
    assert_includes result, "Administrator"
  end

  def test_ternary_erb_non_admin
    result = AutoPreview.render(
      fixture_path("conditionals/ternary.erb"),
      locals: { admin?: false, user: OpenStruct.new(admin?: false) }
    )
    assert_includes result, "User Dashboard"
    assert_includes result, "Regular User"
  end

  # comparisons.erb - just needs to render
  def test_comparisons_erb
    result = AutoPreview.render(fixture_path("conditionals/comparisons.erb"))
    assert_includes result, "Count check passed"
    assert_includes result, "Length check passed"
    assert_includes result, "Equality check passed"
  end

  # case_when.erb - needs status active, pending, inactive, and unknown
  def test_case_when_erb_active
    result = AutoPreview.render(
      fixture_path("conditionals/case_when.erb"),
      locals: { status: "active" }
    )
    assert_includes result, "Active"
    assert_includes result, "badge-green"
  end

  def test_case_when_erb_pending
    result = AutoPreview.render(
      fixture_path("conditionals/case_when.erb"),
      locals: { status: "pending" }
    )
    assert_includes result, "Pending"
    assert_includes result, "badge-yellow"
  end

  def test_case_when_erb_inactive
    result = AutoPreview.render(
      fixture_path("conditionals/case_when.erb"),
      locals: { status: "inactive" }
    )
    assert_includes result, "Inactive"
    assert_includes result, "badge-red"
  end

  def test_case_when_erb_unknown
    result = AutoPreview.render(
      fixture_path("conditionals/case_when.erb"),
      locals: { status: "other" }
    )
    assert_includes result, "Unknown"
    assert_includes result, "badge-gray"
  end

  # final_boss.erb - comprehensive coverage test
  def test_final_boss_erb_coverage
    compiler = AutoPreview::Compiler.new(source_path: fixture_path("final_boss.erb"))
    compiler.compile

    runner = AutoPreview::CoverageRunner.new(compiler)
    runner.run

    # Should have successful outputs
    success_count = runner.results[:outputs].count { |o| o[:success] }
    assert success_count > 0, "Should have at least one successful permutation"
    
    # Debug output
    puts "Permutations: #{runner.results[:permutations_run]}"
    puts "Branch coverage: #{runner.branch_coverage.round(1)}%"
    puts "Line coverage: #{runner.line_coverage.round(1)}%"
    puts "String comparisons: #{runner.results[:string_comparisons].inspect}" if runner.results[:string_comparisons]
    puts "Uncovered branches: #{runner.uncovered_branches.length}"

    # Should achieve good branch coverage
    assert runner.branch_coverage >= 50.0, "Should achieve at least 50% branch coverage, got #{runner.branch_coverage}%"
  end
end
