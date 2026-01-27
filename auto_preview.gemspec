# frozen_string_literal: true

require_relative "lib/auto_preview/version"

Gem::Specification.new do |spec|
  spec.name = "auto_preview"
  spec.version = AutoPreview::VERSION
  spec.authors = ["Joel Hawksley"]
  spec.email = ["joel@hawksley.org"]

  spec.summary = "Auto preview for Rails"
  spec.description = "Automatically preview templates in Rails applications"
  spec.homepage = "https://github.com/joelhawksley/auto_preview"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails"
  spec.add_dependency "actionview_precompiler", "~> 0.4"
end
