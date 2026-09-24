# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require 'zeitwerk'
require 'money'
require 'sequel'
require 'sqlite3'
require 'sidereal'
require 'sidereal/integrations/sourced'
require 'sourced/ui/dashboard'
require 'dotenv'

Dotenv.load(File.expand_path('.env', __dir__))

# SQLite event store + read models, one file. Relative paths resolve
# against the app directory, so rake tasks work from anywhere.
DB_PATH = File.expand_path(ENV.fetch('DATABASE_PATH', 'storage/coffeeshop.db'), __dir__)
FileUtils.mkdir_p(File.dirname(DB_PATH))

# Money
I18n.config.available_locales = :en
Money.default_currency = Money::Currency.new('GBP')
Money.rounding_mode = BigDecimal::ROUND_HALF_EVEN
Money.locale_backend = nil

# Code loading. Everything is eager-loaded so that every message type is
# defined before Sourced compiles its codec and Sidereal locks its registries.
CODE_LOADER = Zeitwerk::Loader.new
CODE_LOADER.push_dir("#{__dir__}/lib")
CODE_LOADER.push_dir("#{__dir__}/domain")
CODE_LOADER.push_dir("#{__dir__}/ui")
CODE_LOADER.setup
CODE_LOADER.eager_load

# Each forked Falcon worker loads this file in its own process, so the
# SQLite connection and the reactors are established fresh per worker.
Sourced.configure do |config|
  # Worker fibers are shared by every consumer group. Reactions such as the
  # payment confirmation hold a fiber for their duration, so give the runtime
  # some headroom.
  config.worker_count = 10

  next if ENV['TEST']

  # IMMEDIATE transactions + a generous busy timeout: the Sourced runtime
  # runs on the elected leader only, but the other Falcon workers still
  # append commands from their HTTP requests.
  config.store = Sequel.sqlite(DB_PATH, timeout: 15_000).tap do |db|
    db.transaction_mode = :immediate
  end
end

Sourced.register(Order)
Sourced.register(Payment)
Sourced.register(OrderListings)
Sourced.register(PaymentListings)
Sourced.register(Deliverables)

# Bridge Sidereal to the Sourced store at runtime only. In TEST the specs
# drive deciders and projectors directly against an in-memory store.
unless ENV['TEST']
  Sidereal.configure do |c|
    # Cross-process pubsub + leader election (unix socket + file lock under
    # ./storage), so SSE updates fan out across Falcon workers.
    c.use_file_system!(dir: File.expand_path('storage', __dir__))
    # Sourced's SQLite store + dispatcher instead of Sidereal's own, plus the
    # error bridge that turns Sourced retries/failures into UI toasts. Pins
    # the Sourced runtime to the elected leader process.
    c.use Sidereal::Integrations::Sourced
  end
end

# Server-side log of terminal failures, on top of the toasts in the UI.
Sidereal.exceptions.on_failure do |report|
  Sourced.config.logger.error("#{report.exception.class}: #{report.exception.message}")
  Sourced.config.logger.error(Array(report.exception.backtrace).join("\n"))
end
