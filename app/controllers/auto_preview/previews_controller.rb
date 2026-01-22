# frozen_string_literal: true

module AutoPreview
  class PreviewsController < ActionController::Base
    def index
      @erb_files = find_erb_files
    end

    def show
      template_path = params[:template]

      if template_path.blank? || !valid_template?(template_path)
        render plain: "Template not found", status: :not_found
        return
      end

      # Remove .html.erb suffix if present since Rails adds it back
      render_path = template_path.sub(/\.html\.erb$/, "")
      render template: render_path, layout: false
    end

    private

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
