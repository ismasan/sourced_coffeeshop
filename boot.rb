# frozen_string_literal: true

require 'zeitwerk'
require 'phlex-sinatra'
require 'money'
require 'sourced'
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
module Phlex
  class SGML
    def helpers = @_context.view_context
  end
end

# Money
I18n.config.available_locales = :en
Money.default_currency = Money::Currency.new("GBP")
Money.rounding_mode = BigDecimal::ROUND_HALF_EVEN
Money.locale_backend = nil

DATABASE_URL = ENV.fetch('DOCKER_DATABASE_URL') {ENV.fetch('DATABASE_URL')}

puts "DATABASE_URL #{DATABASE_URL}"

# Configure Sourced
Sourced.configure do |config|
  config.backend = Sequel.connect(DATABASE_URL)

  config.error_strategy do |s|
    s.retry(times: 1, after: 1)

    s.on_stop do |exception, message|
      Sourced.config.logger.error(exception.backtrace.join("\n"))
    end
  end
end

Sourced.config.backend.install # unless Sourced.config.backend.installed?

# Register Sourced deciders and reactors
Sourced.register(Order)
Sourced.register(OrderListings)
Sourced.register(Payment)

Zeitwerk::Loader.eager_load_all if ENV['RACK_ENV'] == 'production'
