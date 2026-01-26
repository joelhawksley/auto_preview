# frozen_string_literal: true

require "test_helper"

class AutoPreviewSystemTest < SystemTestCase
  test "multi variable template auto-fills and renders" do
    # Visit the index page
    visit "/auto_preview"

    # Select the multi_var template
    select "pages/multi_var.html.erb", from: "template"
    click_button "Preview"

    # Should auto-fill values and render the template directly
    assert_text "Multi Variable Test"
    assert_text "First:"
    assert_text "Second:"

    # Edit overlay should be present with the auto-filled variables
    assert_selector ".auto-preview-fab"
    assert page.html.include?("first_var")
    assert page.html.include?("second_var")
  end

  test "integer type variable via url params" do
    # Test that integer type works when explicitly provided
    visit "/auto_preview/show?template=pages/greeting.html.erb&vars[name][type]=Integer&vars[name][value]=42"

    assert_text "Hello, 42!"
  end

  test "float type variable via url params" do
    visit "/auto_preview/show?template=pages/greeting.html.erb&vars[name][type]=Float&vars[name][value]=3.14"

    assert_text "Hello, 3.14!"
  end

  test "boolean type variable via url params" do
    visit "/auto_preview/show?template=pages/greeting.html.erb&vars[name][type]=Boolean&vars[name][value]=true"

    assert_text "Hello, true!"
  end

  test "array type variable via url params" do
    visit "/auto_preview/show?template=pages/greeting.html.erb&vars[name][type]=Array&vars[name][value]=%5B%22a%22%2C%20%22b%22%5D"

    assert_text "Hello,"
    assert_text "a"
  end

  test "hash type variable via url params" do
    visit "/auto_preview/show?template=pages/greeting.html.erb&vars[name][type]=Hash&vars[name][value]=%7B%22key%22%3A%20%22value%22%7D"

    assert_text "Hello,"
    assert_text "key"
  end

  test "nilclass type variable via url params" do
    visit "/auto_preview/show?template=pages/greeting.html.erb&vars[name][type]=NilClass&vars[name][value]="

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

  test "factory type variable auto-fills and renders user from factory" do
    initial_user_count = User.count

    visit "/auto_preview"

    select "pages/user_card.html.erb", from: "template"
    click_button "Preview"

    # Should auto-detect user factory and render with factory-created user
    assert_text "John Doe"
    assert_text "john@example.com"

    # Factory should be rolled back - no new records persisted
    assert_equal initial_user_count, User.count
  end

  test "factory type variable with trait via url params" do
    initial_user_count = User.count

    visit "/auto_preview/show?template=pages/user_card.html.erb&vars[user][type]=Factory&vars[user][value]=user:admin"

    # Should render the template with admin trait values
    assert_text "Admin User"
    assert_text "admin@example.com"

    # Factory should be rolled back - no new records persisted
    assert_equal initial_user_count, User.count
  end

  # Predicate helper and overlay tests
  test "predicate helper auto-fills and renders" do
    visit "/auto_preview"

    select "pages/conditional_feature.html.erb", from: "template"
    click_button "Preview"

    # Should auto-fill predicate and render the conditional feature page
    assert_text "Conditional Feature Demo"

    # The content will show either premium or basic depending on the predicate value
    # (which may be true from auto-fill or false/nil if helper already existed)
    assert(page.has_text?("Premium User") || page.has_text?("Basic User"))

    # Edit overlay should be present with the auto-filled variables
    assert_selector ".auto-preview-fab"
  end

  test "predicate helper true value shows premium content" do
    # Directly provide all variables via URL to test final rendering
    visit "/auto_preview/show?template=pages/conditional_feature.html.erb&vars[premium_user%3F][type]=Boolean&vars[premium_user%3F][value]=true&vars[user_name][type]=String&vars[user_name][value]=Alice"

    # Should show premium content
    assert_text "Premium User"
    assert_text "Advanced analytics"
    assert_text "Your name: Alice"
  end

  test "predicate helper false value shows basic content" do
    # Directly provide all variables via URL to test final rendering
    visit "/auto_preview/show?template=pages/conditional_feature.html.erb&vars[premium_user%3F][type]=Boolean&vars[premium_user%3F][value]=false&vars[user_name][type]=String&vars[user_name][value]=Bob"

    # Should show basic content
    assert_text "Basic User"
    assert_text "Upgrade to premium"
    assert_text "Your name: Bob"
  end

  test "edit overlay is present after auto-fill rendering" do
    visit "/auto_preview"

    select "pages/greeting.html.erb", from: "template"
    click_button "Preview"

    # Should auto-fill and render content
    assert_text "Hello,"

    # Overlay elements should be present
    assert_selector ".auto-preview-fab"
    assert_selector "#autoPreviewOverlay", visible: false
  end

  test "edit overlay shows existing variables" do
    visit "/auto_preview/show?template=pages/multi_var.html.erb&vars[first_var][type]=String&vars[first_var][value]=hello&vars[second_var][type]=String&vars[second_var][value]=world"

    # Content should be rendered
    assert_text "First: hello"
    assert_text "Second: world"

    # Overlay elements should be in the page (even if hidden)
    assert_selector ".auto-preview-fab"
    # The overlay panel should contain the form with variable names
    assert page.html.include?("first_var")
    assert page.html.include?("second_var")
    assert page.html.include?("Edit Preview Variables")
  end
end
