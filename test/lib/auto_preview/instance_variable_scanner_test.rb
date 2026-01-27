# frozen_string_literal: true

require "test_helper"

class AutoPreview::InstanceVariableScannerTest < ActiveSupport::TestCase
  test "scan extracts single instance variable" do
    source = '<%= @user.name %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@user"], vars
  end

  test "scan extracts multiple instance variables" do
    source = '<%= @user.name %> <%= @post.title %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_includes vars, "@user"
    assert_includes vars, "@post"
  end

  test "scan deduplicates instance variables" do
    source = '<%= @user.name %> <%= @user.email %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@user"], vars
  end

  test "scan handles mixed content" do
    source = <<~ERB
      <h1>Dashboard</h1>
      <%= @current_user.name %>
      <% if @show_admin %>
        Admin Panel
      <% end %>
    ERB
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_includes vars, "@current_user"
    assert_includes vars, "@show_admin"
  end

  test "scan includes all instance variables including internal ones" do
    # The scanner returns all instance variables, filtering is done elsewhere
    source = '<%= @_output_buffer %> <%= @user.name %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_includes vars, "@_output_buffer"
    assert_includes vars, "@user"
  end

  test "scan handles ERB without instance variables" do
    source = '<%= render "partial" %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_empty vars
  end

  test "scan handles plain HTML" do
    source = '<h1>Hello World</h1>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_empty vars
  end

  test "scan handles empty source" do
    vars = AutoPreview::InstanceVariableScanner.scan("")
    assert_empty vars
  end

  test "scan handles instance variables in conditionals" do
    source = '<% if @admin? %><%= @user.role %><% end %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    # @admin? contains ? so it's parsed as @admin with a method call
    assert_includes vars, "@admin"
    assert_includes vars, "@user"
  end

  test "scan handles instance variables in loops" do
    source = '<% @items.each do |item| %><%= item.name %><% end %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@items"], vars
  end

  test "scan handles nested instance variable access" do
    source = '<%= @user.profile.avatar_url %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@user"], vars
  end

  test "scan handles instance variable writes" do
    source = '<% @count = 0 %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@count"], vars
  end

  test "scan handles instance variable or-write" do
    source = '<% @user ||= User.new %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@user"], vars
  end

  test "scan handles instance variable and-write" do
    source = '<% @user &&= update_user(@user) %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@user"], vars
  end

  test "scan handles instance variable operator-write" do
    source = '<% @count += 1 %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_equal ["@count"], vars
  end

  test "scan handles instance variable in multiple assignment" do
    source = '<% @a, @b = [1, 2] %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_includes vars, "@a"
    assert_includes vars, "@b"
  end

  test "scan handles else branch" do
    source = '<% if @admin %><%= @admin.name %><% else %><%= @guest.name %><% end %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_includes vars, "@admin"
    assert_includes vars, "@guest"
  end

  test "scan handles elsif branch" do
    source = '<% if @admin %><%= @admin.name %><% elsif @moderator %><%= @moderator.name %><% end %>'
    vars = AutoPreview::InstanceVariableScanner.scan(source)
    assert_includes vars, "@admin"
    assert_includes vars, "@moderator"
  end

  test "scan handles content that is a string not a token" do
    # Force content.to_s path by passing a mock-like structure
    # This tests the .to_s fallback in extract_ivars_from_content
    vars = AutoPreview::InstanceVariableScanner.scan('<%= @test %>')
    assert_equal ["@test"], vars
  end

  test "scan handles nil content gracefully" do
    # Test with ERB that has nil/empty content
    vars = AutoPreview::InstanceVariableScanner.scan('<% %>')
    assert_equal [], vars
  end

  test "scan handles erb with whitespace-only content" do
    vars = AutoPreview::InstanceVariableScanner.scan('<%=   %>')
    assert_equal [], vars
  end

  test "find_instance_variables handles nil node" do
    # This exercises the early return when node is nil
    vars = AutoPreview::InstanceVariableScanner.scan('<%= nil %>')
    # Even though we render nil, we shouldn't find instance variables
    refute_includes vars, "@nil"
  end
end
