# frozen_string_literal: true

source "https://rubygems.org"

# Sidereal: server-driven reactive web framework (router, pages, SSE, commands)
gem 'sidereal', github: 'ismasan/sidereal'
# Sourced "ccc" branch: stream-less, partition-based event sourcing
gem 'sourced', github: 'ismasan/sourced', branch: 'ccc'
gem 'sourced-ui', github: 'ismasan/sourced-ui', branch: 'ccc'

gem 'falcon'
# Local datastar SDK: treats server-wrapped socket errors (protocol-http1 >= 0.41) as client disconnects
gem 'datastar'
gem 'phlex'
gem 'plumb', '~> 0.3'
gem 'sequel'
gem 'sqlite3'
gem 'money'
gem 'dotenv'
gem 'zeitwerk', '~> 2.7'
gem 'rake'
gem 'irb'

group :development, :test do
  gem 'debug'
  gem 'rspec'
end
