# frozen_string_literal: true

require "test_helper"

class ErbAnalyzerTest < Minitest::Test
  include TestHelper

  def test_analyzes_case_statement
    erb = <<~ERB
      <% case status %>
      <% when :active %>
        Active
      <% when :pending %>
        Pending
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    assert_equal 1, analyzer.case_statements.length
    assert_equal "status", analyzer.case_statements.first[:variable]
    assert_includes analyzer.case_statements.first[:when_values], ":active"
    assert_includes analyzer.case_statements.first[:when_values], ":pending"
  end

  def test_case_values_hash
    erb = <<~ERB
      <% case type %>
      <% when "foo" %>
        Foo
      <% when "bar" %>
        Bar
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    values = analyzer.case_values
    assert_equal ["foo", "bar"], values["type"]
  end

  def test_analyzes_string_when_values
    erb = <<~ERB
      <% case name %>
      <% when "alice" %>
        Alice
      <% when 'bob' %>
        Bob
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    values = analyzer.case_values["name"]
    assert_includes values, "alice"
    assert_includes values, "bob"
  end

  def test_analyzes_multiple_when_values
    erb = <<~ERB
      <% case role %>
      <% when :admin, :superuser %>
        Admin
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    values = analyzer.case_values["role"]
    assert_includes values, ":admin"
    assert_includes values, ":superuser"
  end

  def test_block_conditionals
    erb = <<~ERB
      <% @products.each do |product| %>
        <% if product.in_stock? %>
          Available
        <% end %>
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    bc = analyzer.block_variable_conditions
    assert bc.any? { |b| b[:iterator] == "@products" }
    assert bc.any? { |b| b[:block_var] == "product" }
    assert bc.any? { |b| b[:conditions].include?("in_stock?") }
  end

  def test_block_conditionals_with_if
    # Note: The block conditional detection looks for if/unless using block variable
    erb = <<~ERB
      <% items.each do |item| %>
        <% if item.visible? %>
          Show
        <% end %>
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    bc = analyzer.block_variable_conditions
    assert bc.any? { |b| b[:conditions].include?("visible?") }
  end

  def test_computed_variables_with_method_call
    erb = <<~ERB
      <% owner = repo.owner %>
      <% display_name = owner.name %>
      <%= display_name %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    assert_includes computed, "owner"
    assert_includes computed, "display_name"
  end

  def test_computed_variables_with_or_assign
    erb = <<~ERB
      <% items ||= defaults.items %>
      <%= items.count %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    assert_includes computed, "items"
  end

  def test_computed_variables_with_multi_write
    erb = <<~ERB
      <% a, b = values.split(",") %>
      <%= a %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    assert_includes computed, "a"
    assert_includes computed, "b"
  end

  def test_computed_variables_with_ternary
    erb = <<~ERB
      <% color = dark_mode ? "white" : "black" %>
      <%= color %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    assert_includes computed, "color"
  end

  def test_computed_variables_with_and_or
    erb = <<~ERB
      <% result = a && b %>
      <% other = x || y %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    assert_includes computed, "result"
    assert_includes computed, "other"
  end

  def test_computed_variables_ignores_simple_assigns
    erb = <<~ERB
      <% count = 5 %>
      <% name = "test" %>
      <%= count %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    refute_includes computed, "count"
    refute_includes computed, "name"
  end

  def test_computed_variables_with_parentheses
    erb = <<~ERB
      <% wrapped = (a && b) %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    assert_includes computed, "wrapped"
  end

  def test_computed_variables_with_statements
    erb = <<~ERB
      <% result = begin; compute_value; end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    # Just verify no errors
    assert analyzer.computed_variables.is_a?(Array)
  end

  def test_computed_variables_with_safe_navigation
    erb = <<~ERB
      <% name = user&.name %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    computed = analyzer.computed_variables
    assert_includes computed, "name"
  end

  def test_empty_erb
    analyzer = AutoPreview::ErbAnalyzer.new("")
    analyzer.analyze
    assert_equal [], analyzer.case_statements
    assert_equal [], analyzer.block_variable_conditions
    assert_equal [], analyzer.computed_variables
  end

  def test_erb_without_ruby_code
    erb = "<html><body>Plain HTML</body></html>"
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    assert_equal [], analyzer.case_statements
  end

  def test_nested_case_in_block
    erb = <<~ERB
      <% items.each do |item| %>
        <% case item.type %>
        <% when :a %>
          A
        <% end %>
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    assert analyzer.case_statements.any? { |cs| cs[:variable] == "item.type" }
  end

  def test_if_inside_block_not_using_block_var
    erb = <<~ERB
      <% items.each do |item| %>
        <% if show_all %>
          <%= item %>
        <% end %>
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    # This should NOT add to block_conditionals since condition doesn't use item
    bc = analyzer.block_variable_conditions
    refute bc.any? { |b| b[:conditions].include?("show_all") }
  end

  def test_case_with_constant_when_value
    erb = <<~ERB
      <% case type %>
      <% when TYPE_A %>
        Type A
      <% when TYPE_B %>
        Type B
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    values = analyzer.case_values["type"]
    assert_includes values, "TYPE_A"
    assert_includes values, "TYPE_B"
  end

  def test_erb_if_with_block_context
    # This tests the find_nodes path with block_context passed
    erb = <<~ERB
      <% users.each do |user| %>
        <% if user.admin? %>
          Admin: <%= user.name %>
        <% end %>
      <% end %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    bc = analyzer.block_variable_conditions
    assert bc.any? { |b| b[:block_var] == "user" && b[:conditions].include?("admin?") }
  end

  def test_string_comparisons_with_local_variable
    # Use actual local variable - assignment and comparison must be in the same ERB tag
    # to hit LocalVariableReadNode (otherwise parser sees status as a method call)
    erb = <<~ERB
      <% status = "foo"; active = status == "active" %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    comparisons = analyzer.string_comparisons
    assert_equal ["active"], comparisons["status"]
  end

  def test_string_comparisons_with_method_call
    erb = <<~ERB
      <% show = user.role == "admin" %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    comparisons = analyzer.string_comparisons
    assert_equal ["admin"], comparisons["user.role"]
  end

  def test_string_comparisons_with_instance_variable
    erb = <<~ERB
      <% active = @status == "active" %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    comparisons = analyzer.string_comparisons
    assert_equal ["active"], comparisons["@status"]
  end

  def test_string_comparisons_with_non_string_comparison
    # This should not crash and should not add anything
    erb = <<~ERB
      <% equal = value == 42 %>
      <% match = name == other_name %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    comparisons = analyzer.string_comparisons
    assert_empty comparisons
  end

  def test_computed_variable_dependencies
    erb = <<~ERB
      <% can_edit = can_edit?(user) %>
      <% visible = item.visible? && user.logged_in? %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    deps = analyzer.computed_variable_dependencies
    assert_includes deps["can_edit"], "can_edit?"
    assert_includes deps["visible"], "item.visible?"
    assert_includes deps["visible"], "user.logged_in?"
  end

  def test_computed_variable_dependencies_with_instance_variable_receiver
    # Test build_call_path with InstanceVariableReadNode receiver
    erb = <<~ERB
      <% show = @user.admin? %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    deps = analyzer.computed_variable_dependencies
    assert_includes deps["show"], "@user.admin?"
  end

  def test_string_comparisons_ignores_unsupported_receiver_types
    # Test the else nil fallback in extract_string_comparisons
    # When receiver is something like an array literal, it should be ignored
    erb = <<~ERB
      <% match = [1,2,3] == "foo" %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    comparisons = analyzer.string_comparisons
    assert_empty comparisons
  end

  def test_computed_variable_dependencies_with_complex_receiver
    # Test build_call_path else nil fallback with non-standard receiver
    erb = <<~ERB
      <% result = (a || b).present? %>
    ERB
    analyzer = AutoPreview::ErbAnalyzer.new(erb)
    analyzer.analyze
    deps = analyzer.computed_variable_dependencies
    # The grouped expression (a || b) won't produce a valid path
    # but it shouldn't crash
    assert deps.is_a?(Hash)
  end
end
