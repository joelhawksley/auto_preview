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
require_relative "auto_preview/component_scanner"
require_relative "auto_preview/previews_controller_methods"
require_relative "auto_preview/helper_override_helper"

module AutoPreview
  mattr_accessor :parent_controller
  self.parent_controller = "ActionController::Base"

  # Configuration for helper methods that should be configurable in the UI.
  # Host applications can define these in an initializer:
  #
  #   AutoPreview.helper_methods = {
  #     current_user: :user,           # Uses the :user factory
  #     current_organization: :organization,  # Uses the :organization factory
  #     feature_enabled?: :boolean     # Boolean type
  #   }
  #
  # Supported types:
  #   - Factory name (symbol): Will show factory dropdown in UI
  #   - :boolean: Will show true/false radio buttons in UI
  #   - :string, :integer, :float, :array, :hash: Will show text input
  mattr_accessor :helper_methods
  self.helper_methods = {}
end
