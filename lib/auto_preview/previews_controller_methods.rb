# frozen_string_literal: true

module AutoPreview
  # Controller for the AutoPreview UI. Handles template listing and dispatches
  # rendering to the selected controller context.
  module PreviewsControllerMethods
    extend ActiveSupport::Concern

    RUBY_TYPES = %w[String Integer Float Boolean Array Hash NilClass Factory].freeze

    def index
      @erb_files = find_erb_files
      @controllers = find_controllers
    end

    def show
      template_path = params[:template]
      @controller_context = params[:controller_context] || AutoPreview.parent_controller

      if template_path.blank? || !valid_template?(template_path)
        render plain: "Template not found", status: :not_found
        return
      end

      @template_path = template_path

      # Check if template requires locals that haven't been provided
      required_locals = locals_scanner.locals_for(template_path)
      provided_locals = extract_provided_local_names(params[:vars])
      missing_locals = required_locals - provided_locals

      if missing_locals.any?
        prompt_for_local(missing_locals.first, template_path, @controller_context)
        return
      end

      # Render using the selected controller's context, wrapped in a transaction
      # that gets rolled back to prevent factory-created records from persisting
      render_with_controller_context(@controller_context, template_path, params[:vars])
    end

    private

    def extract_provided_local_names(vars_params)
      return [] unless vars_params.is_a?(ActionController::Parameters) || vars_params.is_a?(Hash)

      vars_params.keys.map(&:to_s)
    end

    def render_with_controller_context(controller_name, template_path, vars_params)
      controller_class = controller_name.constantize
      render_path = template_path.sub(/\.html\.erb$/, "")

      content = nil
      begin
        ActiveRecord::Base.transaction do
          locals = build_locals_from_params(vars_params)
          content = render_template_content(controller_class, render_path, locals)
          raise ActiveRecord::Rollback
        end
        render html: content.html_safe, layout: false
      rescue ActionView::Template::Error => e
        if e.cause.is_a?(NameError)
          handle_name_error(e.cause, template_path)
        else
          raise e
        end
      end
    end

    def render_template_content(controller_class, render_path, locals)
      if controller_class.respond_to?(:render)
        controller_class.render(template: render_path, locals: locals)
      else
        # Fallback for controllers without ActionController::Rendering
        lookup_context = ActionView::LookupContext.new(view_paths)
        view_context = ActionView::Base.with_empty_template_cache.new(lookup_context, locals, self)
        view_context.render(template: render_path, locals: locals)
      end
    end

    def handle_name_error(error, template_path)
      match = error.message.match(/undefined local variable or method [`'](\w+)'/)

      if match
        prompt_for_local(match[1], template_path, @controller_context)
      else
        raise error
      end
    end

    def find_controllers
      controllers = ["ActionController::Base"]

      controller_paths.each do |controller_path|
        path = Pathname.new(controller_path)
        next unless path.exist?

        Dir.glob(path.join("**", "*_controller.rb")).each do |file|
          relative = Pathname.new(file).relative_path_from(path).to_s
          # Convert file path to controller class name
          # e.g., "pages_controller.rb" -> "PagesController"
          # e.g., "admin/users_controller.rb" -> "Admin::UsersController"
          class_name = relative
            .sub(/\.rb$/, "")
            .split("/")
            .map { |part| part.camelize }
            .join("::")

          controllers << class_name
        end
      end

      controllers.uniq.sort
    end

    def locals_scanner
      @locals_scanner ||= LocalsScanner.new(
        view_paths: view_paths,
        controller_paths: controller_paths
      )
    end

    def controller_paths
      Rails.application.config.paths["app/controllers"].expanded
    end

    def prompt_for_local(missing_variable, template_path, controller_context)
      @missing_variable = missing_variable
      @template_path = template_path
      @controller_context = controller_context
      existing = params[:vars]
      @existing_vars = existing.respond_to?(:keys) ? existing : {}
      @ruby_types = RUBY_TYPES
      @factories = find_factories

      render template: "auto_preview/previews/variable_form", layout: false
    end

    def build_locals_from_params(vars_params)
      locals = {}
      return locals unless vars_params.is_a?(ActionController::Parameters) || vars_params.is_a?(Hash)

      vars_params.each do |name, config|
        next unless config.is_a?(ActionController::Parameters) || config.is_a?(Hash)

        type = config[:type]
        value = config[:value]
        locals[name.to_sym] = coerce_value(value, type)
      end

      locals
    end

    def coerce_value(value, type)
      case type
      when "String"
        value.to_s
      when "Integer"
        value.to_i
      when "Float"
        value.to_f
      when "Boolean"
        %w[true 1 yes].include?(value.to_s.downcase)
      when "Array"
        parse_json_or_default(value, [])
      when "Hash"
        parse_json_or_default(value, {})
      when "NilClass"
        nil
      when "Factory"
        create_from_factory(value)
      else
        value.to_s
      end
    end

    def create_from_factory(value)
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

    def find_factories
      return [] unless defined?(FactoryBot)

      FactoryBot.factories.map do |factory|
        traits = factory.defined_traits.map(&:name)
        {name: factory.name.to_s, traits: traits}
      end.sort_by { |f| f[:name] }
    end

    def parse_json_or_default(value, default)
      return default if value.blank?

      JSON.parse(value)
    rescue JSON::ParserError
      default
    end

    def find_erb_files
      files = []

      view_paths.each do |view_path|
        path = Pathname.new(view_path)
        next unless path.exist?

        Dir.glob(path.join("**", "*.html.erb")).each do |file|
          relative = Pathname.new(file).relative_path_from(path).to_s
          files << relative unless relative.start_with?("layouts/", "auto_preview/")
        end
      end

      files.uniq.sort
    end

    def view_paths
      ActionController::Base.view_paths.map(&:to_path)
    end

    def valid_template?(template_path)
      find_erb_files.include?(template_path)
    end
  end
end
