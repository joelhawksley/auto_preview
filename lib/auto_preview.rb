# frozen_string_literal: true

require_relative "auto_preview/version"
require_relative "auto_preview/engine"
require_relative "auto_preview/value_coercer"
require_relative "auto_preview/type_inferrer"
require_relative "auto_preview/variable_extractor"
require_relative "auto_preview/factory_helper"
require_relative "auto_preview/locals_builder"
require_relative "auto_preview/predicate_helper"
require_relative "auto_preview/locals_scanner"
require_relative "auto_preview/coverage_tracker"
require_relative "auto_preview/preset_generator"
require_relative "auto_preview/instance_variable_scanner"
require_relative "auto_preview/previews_controller_methods"

module AutoPreview
  mattr_accessor :parent_controller
  self.parent_controller = "ActionController::Base"
end
