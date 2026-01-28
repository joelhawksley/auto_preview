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
      # Try to load ViewComponent if available
      begin
        require "view_component"
      rescue LoadError
        return []
      end

      return [] unless defined?(ViewComponent::Base)

      # Eager load component files so descendants are populated
      eager_load_components

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

    private

    def eager_load_components
      # Use Rails autoloader paths to find component files
      component_paths.each do |path|
        path_str = path.to_s
        Dir.glob(File.join(path_str, "**", "*_component.rb")).each do |file|
          # Convert file path to class name and constantize to trigger autoloading
          relative_path = file.sub("#{path_str}/", "").sub(/\.rb$/, "")
          class_name = relative_path.camelize
          class_name.constantize
        # :nocov:
        rescue NameError, LoadError
          # Skip files that can't be loaded
        end
        # :nocov:
      end
    end

    def component_paths
      paths = []

      # Check common ViewComponent locations
      if defined?(Rails.root)
        paths << Rails.root.join("app", "components")
        paths << Rails.root.join("app", "views", "components")
      end

      # :nocov:
      # Check ViewComponent config if available
      if defined?(ViewComponent::Base) && ViewComponent::Base.respond_to?(:config)
        config = ViewComponent::Base.config
        if config.respond_to?(:view_component_path)
          custom_path = config.view_component_path
          paths << Rails.root.join(custom_path) if custom_path && defined?(Rails.root)
        end
      end
      # :nocov:

      paths.select { |p| Dir.exist?(p) }
    end
  end
end
