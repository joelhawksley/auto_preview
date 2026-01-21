# frozen_string_literal: true

require_relative "lib/auto_preview/version"

Gem::Specification.new do |spec|
  spec.name = "auto_preview"
  spec.version = AutoPreview::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Render ERB files by automatically mocking out dependencies"
  spec.description = "A Ruby gem that takes a file path to an ERB file and renders it by automatically mocking out any undefined methods or variables."
  spec.homepage = "https://github.com/joelhawksley/auto_preview"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "erb", "~> 4.0"
  spec.add_dependency "herb"
  spec.add_dependency "actionview", ">= 6.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "ostruct"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "simplecov"
end
