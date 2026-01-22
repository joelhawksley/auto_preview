# frozen_string_literal: true

module AutoPreview
  class PreviewsController < ActionController::Base
    def show
      render template: "auto_preview/previews/show", locals: { message: "Hello from AutoPreview!" }
    end
  end
end
