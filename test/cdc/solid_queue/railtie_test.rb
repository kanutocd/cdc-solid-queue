# frozen_string_literal: true

require 'open3'
require 'rake'
require 'rbconfig'
require_relative '../../test_helper'

module Rails
  # Minimal Rails::Railtie stand-in for testing Railtie load behavior.
  class Railtie
    def self.rake_tasks
      yield
    end
  end
end

class RailtieTest < Minitest::Test
  TaskJob = Class.new do
    @payloads = []
    class << self
      attr_reader :payloads

      def perform_later(payload)
        @payloads << payload
      end
    end
  end

  def test_railtie_loads_with_main_api_already_loaded
    load railtie_path

    assert_respond_to CDC::SolidQueue, :configure
    assert_kind_of CDC::SolidQueue::Configuration, CDC::SolidQueue.configuration
  end

  def test_railtie_loads_main_api_in_isolation
    _stdout, stderr, status = Open3.capture3(*isolated_railtie_command)

    assert_predicate status, :success?, stderr
  end

  def test_start_task_runs_runner
    load railtie_path
    Rake::Task.define_task(:environment)
    configure_task

    with_fake_postgresql_stream([{ id: 1 }]) do
      assert_equal 1, CDC::SolidQueue::CLI.start
    end

    assert_equal({ 'id' => 1 }, CDC::SolidQueue::EventSerializer.load(TaskJob.payloads.last))
  end

  def test_start_task_delegates_to_cli
    load railtie_path
    Rake::Task.define_task(:environment)

    with_fake_cli_start(:started) do
      Rake::Task['cdc_solid_queue:start'].reenable
      Rake::Task['cdc_solid_queue:start'].invoke
    end
  end

  def test_railtie_requires_rails_when_no_railtie_is_defined
    _stdout, _stderr, status = Open3.capture3(RbConfig.ruby, '-Ilib', '-e', 'require "cdc/solid_queue/railtie"')

    refute_predicate status, :success?
  end

  private

  def configure_task
    CDC::SolidQueue.reset_configuration!
    CDC::SolidQueue.configure do |config|
      config.processor_job = TaskJob
      config.postgresql = { slot: 'cdc', publication: 'cdc_publication' }
    end
  end

  def with_fake_postgresql_stream(events, &block)
    CDC::SolidQueue::PostgresqlStream.define_singleton_method(:new) { |_configuration| events }
    block.call
  ensure
    CDC::SolidQueue::PostgresqlStream.singleton_class.remove_method(:new)
  end

  def with_fake_cli_start(result, &block)
    singleton_class = CDC::SolidQueue::CLI.singleton_class
    singleton_class.alias_method :original_start_for_railtie_test, :start
    CDC::SolidQueue::CLI.define_singleton_method(:start) { result }
    block.call
  ensure
    singleton_class.remove_method(:start)
    singleton_class.alias_method :start, :original_start_for_railtie_test
    singleton_class.remove_method(:original_start_for_railtie_test)
  end

  def railtie_path
    File.expand_path('../../../lib/cdc/solid_queue/railtie.rb', __dir__)
  end

  def isolated_railtie_command
    [
      RbConfig.ruby,
      '-Ilib',
      '-e',
      isolated_railtie_script
    ]
  end

  def isolated_railtie_script
    <<~RUBY
      module Rails
        class Railtie
          def self.rake_tasks; end
        end
      end

      require "cdc/solid_queue/railtie"
      abort "missing configure" unless CDC::SolidQueue.respond_to?(:configure)
    RUBY
  end
end
