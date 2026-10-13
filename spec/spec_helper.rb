# frozen_string_literal: true

ENV['TEST'] = 'true'

require 'sourced/testing/rspec'
require_relative '../boot'
require 'sequel/core'
Sequel.extension :migration

# Build every component (an in-memory 'db' in TEST), so classes can read
# them. Nothing starts: no pubsub, no workers.
Sidereal.config.build!

# Install the Sourced tables and read models in the in-memory database, so
# projector specs can exercise their sync blocks and class-level queries.
Sequel::Migrator.run(Sourced.store.db, File.expand_path('../db/migrations', __dir__))

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.include Sourced::Testing::RSpec

  config.before do
    OrderListings.on_reset
    PaymentListings.on_reset
    Deliverables.on_reset
  end
end
