# frozen_string_literal: true

require 'zeitwerk'
require 'phlex-sinatra'
require 'money'
require 'sourced'
require 'sourced/ui'
require 'sourced/ui/components'
require 'sequel'
require 'dotenv'
Dotenv.load '.env'

# Setup infrastructure
CODE_LOADER = Zeitwerk::Loader.new

CODE_LOADER.push_dir("#{__dir__}/ui")
CODE_LOADER.push_dir("#{__dir__}/domain")
CODE_LOADER.push_dir("#{__dir__}/lib")

CODE_LOADER.inflector.inflect(
  'openai' => 'OpenAI',
  'ai_expander' => 'AIExpander',
)

CODE_LOADER.setup

$LOAD_PATH.unshift File.dirname(__FILE__)

# Fix Phlex 2.0.0.rc1 to work with Phlex::Sinatra
# module Phlex
#   class SGML
#     def helpers = @_context.view_context
#   end
# end

# Money
I18n.config.available_locales = :en
Money.default_currency = Money::Currency.new("GBP")
Money.rounding_mode = BigDecimal::ROUND_HALF_EVEN
Money.locale_backend = nil

DATABASE_URL = ENV.fetch('DOCKER_DATABASE_URL') {ENV.fetch('DATABASE_URL')}

# Configure Sourced
Sourced.configure do |config|
  unless ENV['TEST']
    # config.backend = Sequel.sqlite('./storage/data.db')
    config.backend = Sequel.connect(DATABASE_URL)
  end

  config.executor = :async

  config.error_strategy do |s|
    s.retry(times: 1, after: 1)

    s.on_stop do |exception, message|
      Sourced.config.logger.error(exception.backtrace.join("\n"))
    end
  end

  # Worker config. These run as fibers within the Falcon process
  # config.worker_count = 10                 # Worker fibers per process (default: 2)
  config.worker_batch_size = 200
  # config.catchup_interval = 5       # Seconds between safety-net polls (default: 5)
  # config.max_drain_rounds = 10      # Max messages per reactor pickup before re-enqueue (default: 10)
  config.housekeeping_count = 1                   # Housekeeper fibers per process (default: 1)
  config.housekeeping_interval = 3               # Seconds between scheduling cycles (default: 3)
  config.housekeeping_heartbeat_interval = 5     # Seconds between worker heartbeats (default: 5)
  config.housekeeping_claim_ttl_seconds = 120    # Seconds before stale claims are reaped (default: 120)
end

Sourced.config.backend.install unless Sourced.config.backend.installed?

# Register Sourced deciders and reactors
Sourced.register(Order)
Sourced.register(OrderListings)
Sourced.register(Payment)
Sourced.register(PaymentListings)
Sourced.register(Deliverables)

Zeitwerk::Loader.eager_load_all if ENV['RACK_ENV'] == 'production'
