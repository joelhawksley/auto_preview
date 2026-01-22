# frozen_string_literal: true

require "test_helper"

class AutoPreviewSystemTest < SystemTestCase
  test "multi variable template happy path" do
    # Visit the index page
    visit "/auto_preview"

    # Select the multi_var template
    select "pages/multi_var.html.erb", from: "template"
    click_button "Preview"

    # Should be prompted for first_var
    assert_text "Missing Variable"
    assert_text "first_var"

    # Fill in first variable
    select "String", from: "var_type"
    fill_in "var_value", with: "Hello"
    click_button "Continue Preview"

    # Should be prompted for second_var
    assert_text "Missing Variable"
    assert_text "second_var"

    # Verify first variable is preserved
    assert_text "Already defined variables"
    assert_text "first_var"

    # Fill in second variable
    select "String", from: "var_type"
    fill_in "var_value", with: "World"
    click_button "Continue Preview"

    # Should render the template with both variables
    assert_text "Multi Variable Test"
    assert_text "First: Hello"
    assert_text "Second: World"
  end

  test "integer type variable" do
    visit "/auto_preview"

    select "pages/greeting.html.erb", from: "template"
    click_button "Preview"

    select "Integer", from: "var_type"
    fill_in "var_value", with: "42"
    click_button "Continue Preview"

    assert_text "Hello, 42!"
  end

  test "float type variable" do
    visit "/auto_preview"

    select "pages/greeting.html.erb", from: "template"
    click_button "Preview"

    select "Float", from: "var_type"
    fill_in "var_value", with: "3.14"
    click_button "Continue Preview"

    assert_text "Hello, 3.14!"
  end

  test "boolean type variable" do
    visit "/auto_preview"

    select "pages/greeting.html.erb", from: "template"
    click_button "Preview"

    select "Boolean", from: "var_type"
    fill_in "var_value", with: "true"
    click_button "Continue Preview"

    assert_text "Hello, true!"
  end

  test "array type variable" do
    visit "/auto_preview"

    select "pages/greeting.html.erb", from: "template"
    click_button "Preview"

    select "Array", from: "var_type"
    fill_in "var_value", with: '["a", "b"]'
    click_button "Continue Preview"

    assert_text "Hello,"
    assert_text "a"
  end

  test "hash type variable" do
    visit "/auto_preview"

    select "pages/greeting.html.erb", from: "template"
    click_button "Preview"

    select "Hash", from: "var_type"
    fill_in "var_value", with: '{"key": "value"}'
    click_button "Continue Preview"

    assert_text "Hello,"
    assert_text "key"
  end

  test "nilclass type variable" do
    visit "/auto_preview"

    select "pages/greeting.html.erb", from: "template"
    click_button "Preview"

    select "NilClass", from: "var_type"
    click_button "Continue Preview"

    assert_text "Hello, !"
  end

  test "template without variables renders directly" do
    visit "/auto_preview"

    select "pages/home.html.erb", from: "template"
    click_button "Preview"

    assert_text "Home Page"
  end

  test "controller context dropdown shows available controllers" do
    visit "/auto_preview"

    # Verify the controller dropdown exists and contains expected controllers
    assert_selector "select#controller_context"

    # Check that discovered controllers are in the dropdown
    assert_selector "select#controller_context option", text: "MinimalController"
    assert_selector "select#controller_context option", text: "PagesController"
  end

  test "rendering with different controller context" do
    visit "/auto_preview"

    # Select a template and MinimalController context
    select "pages/home.html.erb", from: "template"
    select "MinimalController", from: "controller_context"
    click_button "Preview"

    # Should still render successfully even without helpers
    assert_text "Home Page"
  end

  test "factory type variable renders user from factory" do
    initial_user_count = User.count

    visit "/auto_preview"

    select "pages/user_card.html.erb", from: "template"
    click_button "Preview"

    # Should be prompted for user variable
    assert_text "Missing Variable"
    assert_text "user"

    # Select Factory type and enter factory name
    # (rack_test doesn't execute JS, so we fill value directly)
    select "Factory", from: "var_type"
    fill_in "var_value", with: "user"
    click_button "Continue Preview"

    # Should render the template with factory-created user
    assert_text "John Doe"
    assert_text "john@example.com"

    # Factory should be rolled back - no new records persisted
    assert_equal initial_user_count, User.count
  end

  test "factory type variable with trait" do
    initial_user_count = User.count

    visit "/auto_preview"

    select "pages/user_card.html.erb", from: "template"
    click_button "Preview"

    # Select Factory type and enter factory name with trait
    select "Factory", from: "var_type"
    fill_in "var_value", with: "user:admin"
    click_button "Continue Preview"

    # Should render the template with admin trait values
    assert_text "Admin User"
    assert_text "admin@example.com"

    # Factory should be rolled back - no new records persisted
    assert_equal initial_user_count, User.count
  end
end
