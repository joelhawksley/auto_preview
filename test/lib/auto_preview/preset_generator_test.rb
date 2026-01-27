# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class PresetGeneratorTest < ActiveSupport::TestCase
    test "returns empty array for template without conditionals" do
      source = <<~ERB
        <h1>Hello</h1>
        <p><%= user_name %></p>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal [], presets
    end

    test "generates two presets for single if conditional" do
      source = <<~ERB
        <% if premium_user? %>
          <p>Premium content</p>
        <% end %>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal 2, presets.size

      assert_includes presets.map { |p| p[:name] }, "Premium user enabled"
      assert_includes presets.map { |p| p[:name] }, "Premium user disabled"

      enabled_preset = presets.find { |p| p[:name] == "Premium user enabled" }
      assert_equal "Boolean", enabled_preset[:vars]["premium_user?"]["type"]
      assert_equal "true", enabled_preset[:vars]["premium_user?"]["value"]

      disabled_preset = presets.find { |p| p[:name] == "Premium user disabled" }
      assert_equal "false", disabled_preset[:vars]["premium_user?"]["value"]
    end

    test "generates presets for unless conditional" do
      source = <<~ERB
        <% unless logged_in? %>
          <p>Please log in</p>
        <% end %>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal 2, presets.size

      names = presets.map { |p| p[:name] }
      assert_includes names, "Logged in enabled"
      assert_includes names, "Logged in disabled"
    end

    test "generates covering presets for multiple conditionals" do
      source = <<~ERB
        <% if admin? %>
          <p>Admin panel</p>
        <% end %>
        <% if premium_user? %>
          <p>Premium content</p>
        <% end %>
      ERB

      presets = PresetGenerator.generate(source)

      # Should have: all enabled, all disabled, and individual presets
      assert presets.size >= 3

      all_enabled = presets.find { |p| p[:name] == "All features enabled" }
      assert_not_nil all_enabled
      assert_equal "true", all_enabled[:vars]["admin?"]["value"]
      assert_equal "true", all_enabled[:vars]["premium_user?"]["value"]

      all_disabled = presets.find { |p| p[:name] == "All features disabled" }
      assert_not_nil all_disabled
      assert_equal "false", all_disabled[:vars]["admin?"]["value"]
      assert_equal "false", all_disabled[:vars]["premium_user?"]["value"]
    end

    test "generates presets for ternary operator" do
      source = <<~ERB
        <p><%= active? ? "Active" : "Inactive" %></p>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal 2, presets.size
    end

    test "generates presets for if modifier" do
      source = <<~ERB
        <%= "Secret" if show_secret? %>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal 2, presets.size
    end

    test "generates presets for unless modifier" do
      source = <<~ERB
        <%= "Default" unless custom? %>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal 2, presets.size
    end

    test "preserves existing variables in presets" do
      source = <<~ERB
        <% if premium_user? %>
          <p><%= user_name %></p>
        <% end %>
      ERB

      existing_vars = {
        "user_name" => {"type" => "String", "value" => "John"}
      }

      presets = PresetGenerator.generate(source, existing_vars)
      assert_equal 2, presets.size

      preset = presets.first
      assert_equal "String", preset[:vars]["user_name"]["type"]
      assert_equal "John", preset[:vars]["user_name"]["value"]
    end

    test "removes duplicate conditionals" do
      source = <<~ERB
        <% if admin? %>
          <p>Admin</p>
        <% end %>
        <% if admin? %>
          <p>Also admin</p>
        <% end %>
      ERB

      presets = PresetGenerator.generate(source)
      # Should only have 2 presets since it's the same conditional
      assert_equal 2, presets.size
    end

    test "handles non-predicate boolean variables" do
      source = <<~ERB
        <% if show_header %>
          <h1>Header</h1>
        <% end %>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal 2, presets.size

      preset = presets.first
      assert_equal "Boolean", preset[:vars]["show_header"]["type"]
    end

    test "handles existing vars with symbol keys" do
      source = <<~ERB
        <% if premium_user? %>
          <p><%= user_name %></p>
        <% end %>
      ERB

      existing_vars = {
        "user_name" => {type: "String", value: "Jane"}
      }

      presets = PresetGenerator.generate(source, existing_vars)
      preset = presets.first
      assert_equal "String", preset[:vars]["user_name"]["type"]
      assert_equal "Jane", preset[:vars]["user_name"]["value"]
    end

    test "handles existing vars with to_unsafe_h method" do
      source = <<~ERB
        <% if premium_user? %>
          <p><%= user_name %></p>
        <% end %>
      ERB

      # Simulate ActionController::Parameters-like object
      config_obj = Object.new
      def config_obj.to_unsafe_h
        {"type" => "String", "value" => "Bob"}
      end

      existing_vars = {"user_name" => config_obj}

      presets = PresetGenerator.generate(source, existing_vars)
      preset = presets.first
      assert_equal "String", preset[:vars]["user_name"]["type"]
      assert_equal "Bob", preset[:vars]["user_name"]["value"]
    end

    test "handles nil config in existing vars" do
      source = <<~ERB
        <% if premium_user? %>
          <p><%= user_name %></p>
        <% end %>
      ERB

      existing_vars = {"user_name" => nil}

      presets = PresetGenerator.generate(source, existing_vars)
      preset = presets.first
      assert_equal "String", preset[:vars]["user_name"]["type"]
      assert_equal "", preset[:vars]["user_name"]["value"]
    end

    test "skips true/false/nil in ternary detection" do
      source = <<~ERB
        <p><%= true ? "Yes" : "No" %></p>
        <p><%= false ? "Yes" : "No" %></p>
        <p><%= nil ? "Yes" : "No" %></p>
      ERB

      presets = PresetGenerator.generate(source)
      assert_equal [], presets
    end

    test "handles existing vars with only symbol keys no string keys" do
      source = <<~ERB
        <% if premium_user? %>
          <p><%= user_name %></p>
        <% end %>
      ERB

      # Config has only symbol keys, no string keys
      existing_vars = {
        "user_name" => {type: "Integer", value: "42"}
      }

      presets = PresetGenerator.generate(source, existing_vars)
      preset = presets.first
      # Should fall back to symbol keys
      assert_equal "Integer", preset[:vars]["user_name"]["type"]
      assert_equal "42", preset[:vars]["user_name"]["value"]
    end

    test "generates presets with empty existing vars" do
      source = <<~ERB
        <% if show_content? %>
          <p>Content</p>
        <% end %>
      ERB

      presets = PresetGenerator.generate(source, {})
      assert_equal 2, presets.size

      preset = presets.first
      assert_equal({"show_content?" => {"type" => "Boolean", "value" => "true"}}, preset[:vars])
    end
  end
end
