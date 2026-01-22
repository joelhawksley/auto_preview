# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class PreviewsControllerTest < ActionDispatch::IntegrationTest
    def test_show_renders_template_with_message
      get "/auto_preview/previews/show"

      assert_response :success
      assert_includes response.body, "<h1>Hello from AutoPreview!</h1>"
    end
  end
end
