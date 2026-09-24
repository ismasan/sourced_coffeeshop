# frozen_string_literal: true

require_relative 'boot'
require 'sequel/core'
Sequel.extension :migration

MIGRATIONS_DIR = File.expand_path('db/migrations', __dir__)

namespace :db do
  desc 'Run database migrations (Sourced tables + read models)'
  task :migrate do
    Sequel::Migrator.run(Sourced.store.db, MIGRATIONS_DIR)
    puts 'Migrations complete.'
  end

  desc 'Generate the Sourced migration file into db/migrations'
  task :sourced_migration do
    Sourced.store.copy_migration_to do
      File.join(MIGRATIONS_DIR, "#{Time.now.strftime('%Y%m%d%H%M%S')}_create_sourced_tables.rb")
    end
    puts 'Sourced migration file created in db/migrations/'
  end

  desc 'Wipe all messages from the Sourced store and all read model rows'
  task :reset do
    Sourced.store.clear!
    OrderListings.on_reset
    PaymentListings.on_reset
    Deliverables.on_reset
    puts 'All messages and read models deleted.'
  end
end

desc 'Start an IRB session with boot.rb loaded'
task :console do
  require 'irb'
  puts <<~BANNER
    Coffee shop console — store: #{DB_PATH}
      OrderListings.all
      Sourced.load(Order, order_id: 'O...')
      Sidereal.dispatch!(Order::Start.new(payload: { order_id: Order.new_id }))
  BANNER
  ARGV.clear
  IRB.start
end
