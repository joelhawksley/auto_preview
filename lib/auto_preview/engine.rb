# frozen_string_literal: true

module AutoPreview
  class Engine < ::Rails::Engine
    isolate_namespace AutoPreview

    config.to_prepare do
      parent_class = AutoPreview.parent_controller.constantize

      # Remove existing class if it exists (for reloading)
      AutoPreview.send(:remove_const, :PreviewsController) if AutoPreview.const_defined?(:PreviewsController, false)

      # Create the controller class inheriting from the parent
      AutoPreview.const_set(:PreviewsController, Class.new(parent_class) do
        include AutoPreview::PreviewsControllerMethods
        include AutoPreview::Engine.routes.url_helpers
      end)
    end
  end
end
