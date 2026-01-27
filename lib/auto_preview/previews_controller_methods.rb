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

      # Auto-generate values for any missing locals
      vars_params = auto_fill_missing_locals(template_path, params[:vars])

      # Render using the selected controller's context, wrapped in a transaction
      # that gets rolled back to prevent factory-created records from persisting
      render_with_controller_context(@controller_context, template_path, vars_params)
    end

    private

    def render_with_controller_context(controller_name, template_path, vars_params)
      controller_class = controller_name.constantize
      render_path = template_path.sub(/\.html\.erb$/, "")

      content = nil
      coverage = {}
      auto_generated_vars = vars_params || {}
      max_retries = 20  # Prevent infinite loops
      retries = 0

      # Pre-scan template for predicate methods and add them to auto_generated_vars
      # This is needed because predicate helper methods may persist across requests
      template_source = read_template_source(template_path)
      auto_generated_vars = add_scanned_predicates(template_source, auto_generated_vars)

      # Pre-scan template for instance variables and add them to auto_generated_vars
      auto_generated_vars = add_scanned_instance_variables(template_source, auto_generated_vars)

      begin
        ActiveRecord::Base.transaction do
          locals = LocalsBuilder.build_locals(auto_generated_vars)
          predicate_methods = LocalsBuilder.build_predicates(auto_generated_vars)
          assigns = build_assigns(auto_generated_vars)
          coverage, content = CoverageTracker.track(template_path, view_paths) do
            render_template_content(controller_class, render_path, locals, predicate_methods, assigns)
          end
          raise ActiveRecord::Rollback
        end

        @rendered_content = content
        @existing_vars = auto_generated_vars
        @template_source = template_source
        @line_coverage = coverage
        @factories = FactoryHelper.all
        @erb_files = find_erb_files
        @controllers = find_controllers
        @presets = PresetGenerator.generate(@template_source, @existing_vars)

        render template: "auto_preview/previews/show", layout: false
      rescue ActionView::Template::Error => e
        if e.cause.is_a?(NameError) && retries < max_retries
          missing_var = VariableExtractor.extract(e.cause)
          auto_generated_vars = LocalsBuilder.add_auto_generated_value(auto_generated_vars, missing_var)
          retries += 1
          retry
        end
        raise e
      end
    end

    def render_template_content(controller_class, render_path, locals, predicate_methods, assigns = {})
      PredicateHelper.ensure_methods(controller_class, predicate_methods)

      # Merge predicate methods into assigns
      all_assigns = assigns.merge("_auto_preview_predicates" => predicate_methods)

      if controller_class.respond_to?(:render)
        controller_class.render(
          template: render_path,
          locals: locals,
          assigns: all_assigns
        )
      else
        # Fallback for controllers without ActionController::Rendering
        lookup_context = ActionView::LookupContext.new(view_paths)
        view_context = ActionView::Base.with_empty_template_cache.new(lookup_context, locals, self)

        # Set all assigns as instance variables
        all_assigns.each do |name, value|
          view_context.instance_variable_set(:"@#{name}", value)
        end

        predicate_methods.each_key do |method_name|
          view_context.define_singleton_method(method_name.to_sym) do
            (@_auto_preview_predicates || {})[method_name]
          end
        end

        view_context.render(template: render_path, locals: locals)
      end
    end

    def find_controllers
      controllers = ["ActionController::Base"]

      controller_paths.each do |controller_path|
        path = Pathname.new(controller_path)

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

    def auto_fill_missing_locals(template_path, provided_vars)
      required_locals = locals_scanner.locals_for(template_path)
      provided_locals = LocalsBuilder.extract_provided_names(provided_vars)
      missing_locals = required_locals - provided_locals

      return provided_vars if missing_locals.empty?

      vars = provided_vars.respond_to?(:to_unsafe_h) ? provided_vars.to_unsafe_h.deep_dup : (provided_vars || {}).deep_dup

      missing_locals.each do |var_name|
        type, value = TypeInferrer.infer(var_name)
        vars[var_name] = {"type" => type, "value" => value}
      end

      vars
    end

    def find_erb_files
      files = []

      view_paths.each do |view_path|
        path = Pathname.new(view_path)

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

    def read_template_source(template_path)
      full_path = view_paths
        .map { |vp| File.join(vp, template_path) }
        .find { |fp| File.exist?(fp) }
      File.read(full_path)
    end

    # Scan template for predicate method calls and add them to vars if not already present.
    # This ensures predicate variables always appear in the sidebar, even if the helper
    # method was already defined from a previous request.
    def add_scanned_predicates(template_source, vars)
      vars = vars.respond_to?(:to_unsafe_h) ? vars.to_unsafe_h.deep_dup : (vars || {}).deep_dup

      # Pattern to find predicate method calls in ERB: method names ending with ?
      # Uses word boundary before but not after since ? is not a word character
      predicate_pattern = /\b(\w+\?)/

      template_source.scan(predicate_pattern).flatten.uniq.each do |predicate_name|
        # Skip if already in vars
        next if vars.key?(predicate_name) || vars.key?(predicate_name.to_sym)

        # Add the predicate with Boolean type and default value
        type, value = TypeInferrer.infer(predicate_name)
        vars[predicate_name] = {"type" => type, "value" => value}
      end

      vars
    end

    # Scan template for instance variables using Herb AST and add them to vars.
    # Instance variables are prefixed with @ in the vars hash to distinguish them from locals.
    def add_scanned_instance_variables(template_source, vars)
      vars = vars.respond_to?(:to_unsafe_h) ? vars.to_unsafe_h.deep_dup : (vars || {}).deep_dup

      instance_vars = InstanceVariableScanner.scan(template_source)

      instance_vars.each do |ivar_name|
        # Skip internal Rails instance variables
        next if ivar_name.start_with?("@_")

        # Use the full @name as the key to distinguish from locals
        next if vars.key?(ivar_name) || vars.key?(ivar_name.to_sym)

        # Infer type from the variable name (without the @)
        base_name = ivar_name.sub(/^@/, "")
        type, value = TypeInferrer.infer(base_name)
        vars[ivar_name] = {"type" => type, "value" => value}
      end

      vars
    end

    # Build assigns hash from instance variable configs in vars.
    # Only includes entries that start with @ (instance variables).
    def build_assigns(vars)
      assigns = {}
      return assigns unless vars.is_a?(ActionController::Parameters) || vars.is_a?(Hash)

      vars = vars.respond_to?(:to_unsafe_h) ? vars.to_unsafe_h : vars

      vars.each do |name, config|
        next unless name.to_s.start_with?("@")
        next unless config.is_a?(ActionController::Parameters) || config.is_a?(Hash)

        # :nocov: - Both Hash and ActionController::Parameters are tested
        cfg = config.respond_to?(:to_unsafe_h) ? config.to_unsafe_h : config
        # :nocov:
        type = cfg["type"] || cfg[:type] || "String"
        value = cfg["value"] || cfg[:value] || ""

        # Remove the @ prefix for the assign name
        assign_name = name.to_s.sub(/^@/, "")
        assigns[assign_name] = ValueCoercer.coerce(value, type)
      end

      assigns
    end
  end
end
