# frozen_string_literal: true

require_relative 'lib/cdc/solid_queue/version'

Gem::Specification.new do |spec|
  spec.name = 'cdc-solid-queue'
  spec.version = CDC::SolidQueue::VERSION
  spec.authors = ['Ken C. Demanawa']
  spec.email = ['kenneth.c.demanawa@gmail.com']

  spec.summary = 'Rails-native durable CDC job backend for Solid Queue.'
  spec.description = 'Bridges PostgreSQL CDC events into Solid Queue-backed Active Job processors.'
  spec.homepage = 'https://github.com/kanutocd/cdc-solid-queue'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "#{spec.homepage}/tree/main"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['lib/**/*.rb', 'sig/**/*.rbs', 'docs/**/*.md', 'README.md', 'CHANGELOG.md', 'LICENSE.txt']
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'cdc-core', '~> 0.1.3'
  spec.add_dependency 'pgoutput-client', '~> 0.2.4'
  spec.add_dependency 'pgoutput-decoder', '~> 0.1.1'
  spec.add_dependency 'pgoutput-parser', '~> 0.1.1'
  spec.add_dependency 'pgoutput-source-adapter', '~> 0.1.1'
end
