# frozen_string_literal: true

module AutoPreview
  # Helper for working with FactoryBot factories
  class FactoryHelper
    def self.create(value)
      new.create(value)
    end

    def self.all
      new.all
    end

    def create(value)
      return nil unless defined?(FactoryBot)
      return nil if value.blank?

      # Parse factory name and optional traits (e.g., "user" or "user:admin")
      parts = value.to_s.split(":")
      factory_name = parts.first.to_sym
      traits = parts[1..].map(&:to_sym)

      if traits.any?
        FactoryBot.create(factory_name, *traits)
      else
        FactoryBot.create(factory_name)
      end
    end

    def all
      return [] unless defined?(FactoryBot)

      FactoryBot.factories.map do |factory|
        traits = factory.defined_traits.map(&:name)
        {name: factory.name.to_s, traits: traits}
      end.sort_by { |f| f[:name] }
    end
  end
end
