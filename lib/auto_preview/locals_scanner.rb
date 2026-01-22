# frozen_string_literal: true

require "actionview_precompiler"

module AutoPreview
  # Scans templates and controllers to extract locals passed to each template via render calls.
  # Uses actionview_precompiler to parse Ruby code and find render invocations.
  class LocalsScanner
    def initialize(view_paths:, controller_paths: [])
      @view_paths = view_paths
      @controller_paths = controller_paths
      @template_locals = nil
    end

    # Returns a hash mapping virtual paths to arrays of local variable names
    # e.g. { "users/_user" => ["user", "admin"], "pages/_sidebar" => ["items"] }
    def template_locals
      @template_locals ||= scan_all
    end

    # Get locals for a specific template path (e.g. "pages/greeting.html.erb")
    def locals_for(template_path)
      # Convert template path to virtual path format
      virtual_path = template_path_to_virtual_path(template_path)

      # Look up locals, checking both partial and non-partial versions
      template_locals[virtual_path] || template_locals[partialize(virtual_path)] || []
    end

    private

    def scan_all
      locals = Hash.new { |h, k| h[k] = Set.new }

      # Scan view directories for render calls in templates
      @view_paths.each do |view_path|
        scan_view_directory(view_path, locals)
      end

      # Scan controller directories for render calls
      @controller_paths.each do |controller_path|
        scan_controller_directory(controller_path, locals)
      end

      # Convert Sets to sorted Arrays
      locals.transform_values { |v| v.to_a.sort }
    end

    def scan_view_directory(view_dir, locals)
      return unless File.directory?(view_dir)

      scanner = ActionviewPrecompiler::TemplateScanner.new(view_dir)
      scanner.template_renders.each do |virtual_path, local_keys|
        locals[virtual_path].merge(local_keys)
      end
    end

    def scan_controller_directory(controller_dir, locals)
      return unless File.directory?(controller_dir)

      scanner = ActionviewPrecompiler::ControllerScanner.new(controller_dir)
      scanner.template_renders.each do |virtual_path, local_keys|
        locals[virtual_path].merge(local_keys)
      end
    end

    def template_path_to_virtual_path(template_path)
      # Remove all extensions (e.g., ".html.erb" -> "")
      # The regex matches from the first dot to the end of the path
      template_path.sub(/\.[^\/]+\z/, "")
    end

    def partialize(virtual_path)
      # Convert "pages/greeting" to "pages/_greeting"
      parts = virtual_path.split("/")
      return virtual_path if parts.empty?

      parts[-1] = "_#{parts[-1]}" unless parts[-1].start_with?("_")
      parts.join("/")
    end
  end
end
