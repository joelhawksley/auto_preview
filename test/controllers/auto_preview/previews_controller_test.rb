# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class PreviewsControllerTest < ActionDispatch::IntegrationTest
    def test_index_renders_template_selector
      get "/auto_preview"

      assert_response :success
      assert_includes response.body, "<h1>AutoPreview</h1>"
      assert_includes response.body, "<select"
      assert_includes response.body, "pages/home.html.erb"
      assert_includes response.body, "pages/about.html.erb"
    end

    def test_index_excludes_layouts
      get "/auto_preview"

      assert_response :success
      refute_includes response.body, "layouts/application"
    end

    def test_show_renders_selected_template
      get "/auto_preview/show", params: { template: "pages/home.html.erb" }

      assert_response :success
      assert_includes response.body, "<h1>Home Page</h1>"
    end

    def test_show_returns_not_found_for_missing_template
      get "/auto_preview/show", params: { template: "nonexistent/template" }

      assert_response :not_found
      assert_includes response.body, "Template not found"
    end

    def test_show_returns_not_found_for_blank_template
      get "/auto_preview/show", params: { template: "" }

      assert_response :not_found
    end

    def test_show_returns_not_found_without_template_param
      get "/auto_preview/show"

      assert_response :not_found
    end
  end

  class PreviewsControllerUnitTest < ActiveSupport::TestCase
    def test_find_erb_files_returns_empty_when_views_path_missing
      controller = PreviewsController.new
      temp_dir = Dir.mktmpdir

      controller.stub(:view_paths, [File.join(temp_dir, "nonexistent")]) do
        result = controller.send(:find_erb_files)
        assert_equal [], result
      end
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir
    end
  end
end
