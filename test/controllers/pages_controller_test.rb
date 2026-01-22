# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  def test_home_renders_successfully
    get "/pages/home"

    assert_response :success
    assert_includes response.body, "Home Page"
  end

  def test_about_renders_successfully
    get "/pages/about"

    assert_response :success
    assert_includes response.body, "About Page"
  end
end
