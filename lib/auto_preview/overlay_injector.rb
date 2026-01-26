# frozen_string_literal: true

module AutoPreview
  # Injects overlay HTML into page content
  class OverlayInjector
    def self.inject(content, overlay_html)
      new.inject(content, overlay_html)
    end

    def inject(content, overlay_html)
      return content if overlay_html.blank?

      if content.match?(%r{</body>}i)
        content.sub(%r{</body>}i, "#{overlay_html}\n</body>")
      else
        content + overlay_html
      end
    end
  end
end
