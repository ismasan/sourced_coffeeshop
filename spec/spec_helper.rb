# frozen_string_literal: true

ENV['TEST'] = 'true'

require 'sourced/testing/rspec'
require_relative '../boot'
require 'sequel/core'
Sequel.extension :migration

# In TEST boot.rb leaves Sourced on an in-memory SQLite store. Create the
# read model tables there too, so projector specs can exercise their sync
# blocks and class-level queries.
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
