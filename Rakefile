# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'
require 'yard'

Rake::TestTask.new(:test) do |task|
  task.libs << 'test'
  task.pattern = 'test/**/*_test.rb'
  task.warning = true
end

RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ['--cache', 'false']
end

YARD::Rake::YardocTask.new(:yard)

desc 'Enforce complete public API documentation'
task :yard_coverage do
  sh 'bundle exec yard stats --list-undoc --compact | tee /tmp/cdc-redis-pro-yard-stats'
  sh "grep -F '100.00% documented' /tmp/cdc-redis-pro-yard-stats"
end

namespace :rbs do
  desc 'Validate signatures and statically check the implementation'
  task :validate do
    sh 'bundle exec rbs -I sig -r cdc-core validate'
    sh 'bundle exec steep check'
  end
end

namespace :smoke do
  desc 'Run local smoke tests'
  task :local do
    ruby 'smoke_tests/enqueue_smoke.rb'
    ruby 'smoke_tests/runner_checkpoint_smoke.rb'
  end
end

namespace :benchmark do
  desc 'Benchmark enqueue serialization and dispatch overhead'
  task :enqueue do
    ruby 'benchmark/enqueue_benchmark.rb'
  end
end

desc 'Run tests with strict line and branch coverage thresholds'
task :coverage do
  sh({ 'COVERAGE' => 'true' }, 'bundle exec rake test')
end

task quality: %i[rubocop coverage smoke:local rbs:validate yard_coverage]
task default: :quality
