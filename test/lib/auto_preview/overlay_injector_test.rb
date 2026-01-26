# frozen_string_literal: true

require "test_helper"

module AutoPreview
  class OverlayInjectorTest < ActiveSupport::TestCase
    def test_inject_with_body_tag
      content = "<html><body><h1>Test</h1></body></html>"
      overlay = "<div>Overlay</div>"

      result = OverlayInjector.inject(content, overlay)

      assert_includes result, "<div>Overlay</div>"
      assert_includes result, "</body>"
      assert result.index("<div>Overlay</div>") < result.index("</body>")
    end

    def test_inject_without_body_tag
      content = "<h1>Test</h1>"
      overlay = "<div>Overlay</div>"

      result = OverlayInjector.inject(content, overlay)

      assert_equal "<h1>Test</h1><div>Overlay</div>", result
    end

    def test_inject_with_blank_overlay
      content = "<html><body><h1>Test</h1></body></html>"

      assert_equal content, OverlayInjector.inject(content, "")
      assert_equal content, OverlayInjector.inject(content, nil)
    end
  end
end
