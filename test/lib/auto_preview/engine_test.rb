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
  end
end
