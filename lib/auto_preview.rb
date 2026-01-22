# frozen_string_literal: true

require_relative "auto_preview/version"
require_relative "auto_preview/engine"
require_relative "auto_preview/locals_scanner"
require_relative "auto_preview/previews_controller_methods"

module AutoPreview
  mattr_accessor :parent_controller
  self.parent_controller = "ActionController::Base"
end
