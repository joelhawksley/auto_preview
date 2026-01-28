# frozen_string_literal: true

module AutoPreview
  # Scans ViewComponent classes to extract their initialize parameters
  class ComponentScanner
    def self.scan(component_class)
      new.scan(component_class)
    end

    def self.find_components
      new.find_components
    end

    def scan(component_class)
      return [] unless component_class.respond_to?(:instance_method)

      begin
        init_method = component_class.instance_method(:initialize)
      # :nocov:
      rescue NameError
        return []
      end
      # :nocov:

      params = init_method.parameters
      params.map do |type, name|
        {
          name: name.to_s,
          required: type == :req || type == :keyreq,
          keyword: type == :key || type == :keyreq,
          type: type
        }
      end.reject { |p| p[:name].empty? }
    end

    def find_components
      return [] unless defined?(ViewComponent::Base)

      ViewComponent::Base.descendants
        .select { |klass| klass.name.present? } # Skip anonymous classes
        .map do |klass|
          {
            name: klass.name,
            params: scan(klass)
          }
        end
        .sort_by { |c| c[:name] }
    end
  end
end
