# frozen_string_literal: true

require_relative "lib/graditude_factory/version"

Gem::Specification.new do |spec|
  spec.name = "graditude_factory"
  spec.version = GraditudeFactory::VERSION
  spec.authors = [ "Christopher Unger" ]
  spec.email = [ "contact@christopherunger.com" ]

  spec.summary = "Generic template-based certificate PDF generation for Rails"
  spec.description = "A flexible certificate generation engine using Prawn, supporting custom templates, multiple schools, and PNG rendering."
  spec.homepage = "https://github.com/christopherunger/graditude_factory"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Runtime dependencies
  spec.add_runtime_dependency "prawn-rails", ">= 0.0.11"
  spec.add_runtime_dependency "prawn-svg", ">= 0.32.0"
  spec.add_runtime_dependency "pdftoimage", ">= 0.2.1"
  spec.add_runtime_dependency "railties", ">= 6.0"

  # Development dependencies
  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "rails", ">= 6.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
end
