# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class EngineTest < ActiveSupport::TestCase
    def test_engine_recreates_controller_on_reload
      # Simulate code reloading by triggering to_prepare again
      # This should remove and recreate the PreviewsController constant
      assert AutoPreview.const_defined?(:PreviewsController, false)

      # Trigger the to_prepare callback manually
      Rails.application.reloader.prepare!

      # Controller should still exist and work
      assert AutoPreview.const_defined?(:PreviewsController, false)
      assert AutoPreview::PreviewsController < ApplicationController
    end

    def test_engine_creates_controller_when_not_defined
      # Test the else branch - when PreviewsController doesn't exist yet
      # Remove it first
      AutoPreview.send(:remove_const, :PreviewsController)
      refute AutoPreview.const_defined?(:PreviewsController, false)

      # Trigger to_prepare - should create the controller
      Rails.application.reloader.prepare!

      # Controller should now exist
      assert AutoPreview.const_defined?(:PreviewsController, false)
      assert AutoPreview::PreviewsController < ApplicationController
    end

    def test_engine_auto_mounts_routes_in_development
      # Test that the initializer mounts routes when in development environment
      Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
        block_executed = false
        mounted_engine = nil
        mounted_at = nil

        # Create a mock app with routes that captures the block and executes it
        mock_routes = Object.new
        mock_routes.define_singleton_method(:append) do |&block|
          # Create a context that captures mount calls
          context = Object.new
          context.define_singleton_method(:mount) do |engine, options|
            mounted_engine = engine
            mounted_at = options[:at]
            block_executed = true
          end
          context.instance_eval(&block)
        end

        mock_app = Object.new
        mock_app.define_singleton_method(:routes) { mock_routes }

        # Find and run the auto_preview.routes initializer
        initializer = AutoPreview::Engine.initializers.find { |i| i.name == "auto_preview.routes" }
        initializer.run(mock_app)

        assert block_executed, "Routes block should be executed in development environment"
        assert_equal AutoPreview::Engine, mounted_engine
        assert_equal "/auto_preview", mounted_at
      end
    end

    def test_engine_does_not_mount_routes_in_non_development
      # Test that the initializer does NOT mount routes when not in development
      Rails.stub(:env, ActiveSupport::StringInquirer.new("test")) do
        routes_mounted = false

        mock_routes = Object.new
        mock_routes.define_singleton_method(:append) { routes_mounted = true }

        mock_app = Object.new
        mock_app.define_singleton_method(:routes) { mock_routes }

        # Find and run the auto_preview.routes initializer
        initializer = AutoPreview::Engine.initializers.find { |i| i.name == "auto_preview.routes" }
        initializer.run(mock_app)

        refute routes_mounted, "Routes should NOT be mounted in test environment"
      end
    end
  end
end
