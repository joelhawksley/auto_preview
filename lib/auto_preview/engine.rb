# frozen_string_literal: true

module AutoPreview
  class Engine < ::Rails::Engine
    isolate_namespace AutoPreview

    config.to_prepare do
      # Dynamically create PreviewsController inheriting from the configured parent
      parent_class = AutoPreview.parent_controller.constantize

      # Remove existing class if it exists (for reloading)
      AutoPreview.send(:remove_const, :PreviewsController) if AutoPreview.const_defined?(:PreviewsController, false)

      # Capture the helpers module before defining the class
      parent_helpers = parent_class._helpers

      # Create the controller class inheriting from the parent
      AutoPreview.const_set(:PreviewsController, Class.new(parent_class) do
        include AutoPreview::PreviewsControllerMethods
        include AutoPreview::Engine.routes.url_helpers

        # Include the parent's helpers so templates can use host app helpers
        helper parent_helpers
      end)
    end
  end
end
