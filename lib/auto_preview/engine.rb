# frozen_string_literal: true

module AutoPreview
  class Engine < ::Rails::Engine
    isolate_namespace AutoPreview

    # Automatically mount routes in development environment
    initializer "auto_preview.routes", after: :add_routing_paths do |app|
      if Rails.env.development?
        app.routes.append do
          unless app.routes.named_routes.key?(:auto_preview)
            mount AutoPreview::Engine, at: "/auto_preview"
          end
        end
      end
    end

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
