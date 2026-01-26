# frozen_string_literal: true

module AutoPreview
  # Extracts variable names from NameError/NoMethodError messages
  class VariableExtractor
    PATTERN = /undefined (?:local variable or )?method [`']([\w\?]+)'/

    def self.extract(error)
      new.extract(error)
    end

    def extract(error)
      match = error.message.match(PATTERN)
      match ? match[1] : nil
    end
  end
end
