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

# The app's SQLite database: the Sourced message log plus the read models.
# A component, so each forked Falcon worker opens its own connection when its
# host starts (SQLite connections aren't fork-safe) and disconnects it on
# shutdown. In TEST it is a fresh in-memory database.
Sidereal.config.declare('db', Sequel::Database)
Sidereal.config.component!('db') do
  build do
    if ENV['TEST']
      Sequel.sqlite
    else
      # IMMEDIATE transactions + a generous busy timeout: the Sourced runtime
      # runs on the elected leader only, but the other Falcon workers still
      # append commands from their HTTP requests.
      Sequel.sqlite(DB_PATH, timeout: 15_000).tap do |db|
        db.transaction_mode = :immediate
      end
    end
  end
  teardown(&:disconnect)
end

# Cross-process pubsub + leader election (unix socket + file lock under
# ./storage), so SSE updates fan out across Falcon workers.
Sidereal.config.use_file_system!(dir: File.expand_path('storage', __dir__))

# Sourced's store (on the 'db' component) + dispatcher instead of Sidereal's
# own, plus the error bridge that turns Sourced retries/failures into UI
# toasts. Mounts Sourced's configuration at 'sourced' and pins its runtime to
# the elected leader process. Nothing is built or started here: rake tasks and
# specs call Sidereal.config.build!, and each Falcon worker starts it.
Sidereal.config.use Sidereal::Integrations::Sourced, db: 'db'

# Worker fibers are shared by every consumer group. Reactions such as the
# payment confirmation hold a fiber for their duration, so give the runtime
# some headroom.
Sidereal.config.config!('sourced.workers.count') { 10 }

Sourced.register(Order)
Sourced.register(Payment)
Sourced.register(OrderListings)
Sourced.register(PaymentListings)
Sourced.register(Deliverables)

# Server-side log of terminal failures, on top of the toasts in the UI.
Sidereal.exceptions.on_failure do |report|
  Sourced.logger.error("#{report.exception.class}: #{report.exception.message}")
  Sourced.logger.error(Array(report.exception.backtrace).join("\n"))
end
