# frozen_string_literal: true

require "test_helper"

class ConditionalsTest < Minitest::Test
  include TestHelper

  def test_if_statement_with_mocked_variable
    result = AutoPreview.render(fixture_path("conditionals/if_statement.erb"))
    # Mocked values are truthy by default, so the if branch should be taken
    assert_includes result, "User is logged in"
  end

  def test_if_else_statement
    result = AutoPreview.render(fixture_path("conditionals/if_else.erb"))
    # Should take the truthy branch
    assert_includes result, "Welcome back"
  end

  def test_if_else_statement_false_branch
    result = AutoPreview.render(
      fixture_path("conditionals/if_else.erb"),
      mock_values: { user: OpenStruct.new(returning?: false) }
    )
    # Should take the else branch
    assert_includes result, "Welcome, new visitor"
  end

  def test_if_statement_with_explicit_false
    result = AutoPreview.render_string(
      "<% if logged_in %>Logged in<% else %>Please log in<% end %>",
      locals: { logged_in: false }
    )
    assert_includes result, "Please log in"
    refute_includes result, "Logged in"
  end

  def test_if_statement_with_explicit_true
    result = AutoPreview.render_string(
      "<% if logged_in %>Logged in<% else %>Please log in<% end %>",
      locals: { logged_in: true }
    )
    assert_includes result, "Logged in"
    refute_includes result, "Please log in"
  end

  def test_unless_statement
    result = AutoPreview.render(fixture_path("conditionals/unless_statement.erb"))
    # Mocked any? returns false, so unless block WILL execute
    assert_includes result, "No items found"
  end

  def test_unless_statement_with_items
    items = [OpenStruct.new(name: "Item 1"), OpenStruct.new(name: "Item 2")]
    result = AutoPreview.render(
      fixture_path("conditionals/unless_statement.erb"),
      locals: { items: items }
    )
    # Items exist, so unless block should NOT execute, but each should
    refute_includes result, "No items found"
    assert_includes result, "Item 1"
    assert_includes result, "Item 2"
  end

  def test_ternary_operator
    result = AutoPreview.render(fixture_path("conditionals/ternary.erb"))
    # Mocked admin? is truthy
    assert_includes result, "Admin Dashboard"
  end

  def test_comparison_operators
    result = AutoPreview.render(fixture_path("conditionals/comparisons.erb"))
    # Test that comparisons work with mocked values
    assert_includes result, "Count check passed"
  end

  def test_and_or_operators
    result = AutoPreview.render_string(
      "<% if user && user.active? %>Active user<% end %>",
    )
    assert_includes result, "Active user"
  end

  def test_nil_check
    result = AutoPreview.render_string(
      "<% if item.nil? %>Item is nil<% else %>Item exists<% end %>"
    )
    # MockValue.nil? returns false
    assert_includes result, "Item exists"
  end

  def test_present_check
    result = AutoPreview.render_string(
      "<% if items.present? %>Has items<% else %>No items<% end %>"
    )
    # MockValue.present? returns true
    assert_includes result, "Has items"
  end

  def test_blank_check
    result = AutoPreview.render_string(
      "<% if items.blank? %>Blank<% else %>Not blank<% end %>"
    )
    # MockValue.blank? returns false
    assert_includes result, "Not blank"
  end

  def test_case_when_statement
    result = AutoPreview.render(fixture_path("conditionals/case_when.erb"))
    # Should render without errors - mocked status hits else branch
    assert_includes result, "Unknown"
  end

  def test_case_when_active
    result = AutoPreview.render(
      fixture_path("conditionals/case_when.erb"),
      locals: { status: "active" }
    )
    assert_includes result, "Active"
    assert_includes result, "badge-green"
  end

  def test_case_when_pending
    result = AutoPreview.render(
      fixture_path("conditionals/case_when.erb"),
      locals: { status: "pending" }
    )
    assert_includes result, "Pending"
    assert_includes result, "badge-yellow"
  end

  def test_case_when_inactive
    result = AutoPreview.render(
      fixture_path("conditionals/case_when.erb"),
      locals: { status: "inactive" }
    )
    assert_includes result, "Inactive"
    assert_includes result, "badge-red"
  end
end
