# frozen_string_literal: true

module AutoPreview
  # Controller for the AutoPreview UI. Handles template listing and dispatches
  # rendering to the selected controller context.
  module PreviewsControllerMethods
    extend ActiveSupport::Concern

    RUBY_TYPES = %w[String Integer Float Boolean Array Hash NilClass].freeze

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
      @locals = build_locals_from_params

      # Check if template requires locals that haven't been provided
      required_locals = locals_scanner.locals_for(template_path)
      provided_locals = @locals.keys.map(&:to_s)
      missing_locals = required_locals - provided_locals

      if missing_locals.any?
        prompt_for_local(missing_locals.first, template_path, @controller_context)
        return
      end

      # Render using the selected controller's context
      render_with_controller_context(@controller_context, template_path, @locals)
    end

    private

    def render_with_controller_context(controller_name, template_path, locals)
      controller_class = controller_name.constantize
      render_path = template_path.sub(/\.html\.erb$/, "")

      # Create a view context with the target controller's helpers
      helpers_module = controller_class._helpers if controller_class.respond_to?(:_helpers)
      view_context_class = Class.new(ActionView::Base)
      view_context_class.include(helpers_module) if helpers_module

      lookup_context = ActionView::LookupContext.new(view_paths)
      view_context = view_context_class.with_empty_template_cache.new(lookup_context, locals, self)

      begin
        content = view_context.render(template: render_path, locals: locals)
        render html: content.html_safe, layout: false
      rescue ActionView::Template::Error => e
        if e.cause.is_a?(NameError)
          handle_name_error(e.cause, template_path)
        else
          raise e
        end
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

      render template: "auto_preview/previews/variable_form", layout: false
    end

    def build_locals_from_params
      locals = {}
      return locals unless params[:vars].is_a?(ActionController::Parameters) || params[:vars].is_a?(Hash)

      params[:vars].each do |name, config|
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
      else
        value.to_s
      end
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
          files << relative unless relative.start_with?("layouts/") || relative.start_with?("auto_preview/")
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
