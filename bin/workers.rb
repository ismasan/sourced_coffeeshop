# frozen_string_literal: true

require_relative './../boot'

# falcon.rb runs workers as sidecar fibers
# bin/workers.rb is only needed when not using Falcon
Sourced::Supervisor.start(count: 10)
