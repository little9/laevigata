# frozen_string_literal: true

unless ENV['NO_COVERAGE'] == 'true'
  require 'coveralls'
  Coveralls.wear!('rails')
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
require 'devise'
require 'devise/version'
require 'rspec/its'
require 'rspec/matchers'
require 'rspec/active_model/mocks'
require 'active_fedora/cleaner'
require 'capybara/rspec'
require 'capybara/rails'
require 'capybara-screenshot/rspec'
require 'capybara/webkit'
require 'database_cleaner'
require 'hyrax/spec/factory_bot/build_strategies'
require 'noid/rails/rspec'
require 'ffaker'
require 'webmock/rspec'
require 'vcr'

WebMock.allow_net_connect!

VCR.configure do |config|
  config.ignore_hosts '127.0.0.1', 'localhost'
  config.cassette_library_dir = "#{::Rails.root}/spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = true
end

# capybara testing
Capybara.javascript_driver = :webkit

Capybara::Webkit.configure do |config|
  # config.debug = true
  config.raise_javascript_errors = true
end

# Require support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

# See https://github.com/thoughtbot/shoulda-matchers#rspec
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  include Noid::Rails::RSpec

  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  ENV['REGISTRAR_DATA_PATH'] = "#{::Rails.root}/spec/fixtures/registrar_sample.json"
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!

  config.before :suite do
    disable_production_minter!
    DatabaseCleaner.clean_with(:truncation)
    ActiveFedora::Cleaner.clean!
  end

  config.after :suite do
    enable_production_minter!
  end

  config.before clean: true do
    DatabaseCleaner.clean
    ActiveFedora::Cleaner.clean!
  end

  config.after clean: true do
    DatabaseCleaner.clean
    ActiveFedora::Cleaner.clean!
  end

  config.before do
    DatabaseCleaner.strategy = :transaction
  end

  config.before js: true do
    DatabaseCleaner.strategy = :truncation
  end

  config.before perform_jobs: true do
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
  end

  config.after perform_jobs: true do
    ActiveJob::Base.queue_adapter.filter                = nil
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
  end

  config.before(:example, :workflow) do |example|
    DatabaseCleaner.clean
    ActiveFedora::Cleaner.clean!

    workflow_settings = example.metadata[:workflow].try(:to_h) || {}
    workflow_settings = { superusers_config: "#{fixture_path}/config/emory/superusers.yml",
                          admin_sets_config: "#{fixture_path}/config/emory/ec_admin_sets.yml",
                          log_location:      "/dev/null" }.merge(workflow_settings)

    setup_args = [workflow_settings[:superusers_config],
                  workflow_settings[:admin_sets_config],
                  workflow_settings[:log_location]]

    WorkflowSetup.new(*setup_args).setup
  end

  config.after(:example, :workflow) do |example|
    DatabaseCleaner.clean
    ActiveFedora::Cleaner.clean!
  end

  config.before do
    DatabaseCleaner.start
    class_double("Clamby").as_stubbed_const
    allow(Clamby).to receive(:virus?).and_return(false)
  end

  config.append_after do
    DatabaseCleaner.clean
  end

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Capybara::RSpecMatchers, type: :input

  config.include Warden::Test::Helpers, type: :feature
  config.after(:each, type: :feature) { Warden.test_reset! }

  # get this value once, then check variable in each test
  new_ui = false
  %i[feature view].each do
    config.before(:all) do
      new_ui = Rails.application.config_for(:new_ui).fetch('enabled', false)
    end
  end

  # because we need to negate with skip, these conditionals are a little awkward, but they do control the flow correctly.
  # this is the flow we want:
  # when env new_ui is true, only run tests tagged new_ui
  # when env new_ui is false, only run tests without new_ui tag

  config.before(:each, type: :feature) do |example|
    if new_ui
      skip('Hyrax Feature tests do not run when NEW_UI_ENABLED') unless example.metadata[:new_ui]
    end

    skip("New UI Feature tests run only when NEW_UI_ENABLED") if !new_ui && example.metadata[:new_ui]
  end

  config.before(:all, type: :view) do
    skip("View tests run only when NEW_UI_ENABLED") unless new_ui
  end

  # Gets around a bug in RSpec where helper methods that are defined in views aren't
  # getting scoped correctly and RSpec returns "does not implement" errors. So we
  # can disable verify_partial_doubles if a particular test is giving us problems.
  # Ex:
  #   describe "problem test", verify_partial_doubles: false do
  #     ...
  #   end
  config.before do |example|
    config.mock_with :rspec do |mocks|
      mocks.verify_partial_doubles = example.metadata.fetch(:verify_partial_doubles, true)
    end
  end
end
