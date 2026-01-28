# frozen_string_literal: true

# Test component for AutoPreview testing
class ButtonComponent < ViewComponent::Base
  def initialize(label:, variant: "primary", disabled: false)
    @label = label
    @variant = variant
    @disabled = disabled
  end

  attr_reader :label, :variant, :disabled
end
