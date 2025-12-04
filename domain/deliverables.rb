class Deliverables < Sourced::Projector::EventSourced
  DATA_DIR = './storage/deliverables'

  module System
    Updated = ::Sourced::Event.define('deliverables.system.updated')
  end

  def self.all(limit: 100)
    list = Dir[File.join(DATA_DIR, '*.json')].map do |file|
      JSON.parse(File.read(file), symbolize_names: true)
    end.sort_by { |r| r[:sort] }.reverse

    limit ? list.take(limit) : list
  end

  # This block runs in a transaction when handling events
  # Just write order listings to JSON files
  sync do |state:, events:, replaying:|
    path = File.join(DATA_DIR, "#{state[:id]}.json")

    FileUtils.mkdir_p(DATA_DIR)

    if state[:status] == 'ready'
      File.write(path, JSON.pretty_generate(state.to_h))
    elsif state[:status] == 'delivered' && File.exist?(path)
      File.unlink(path)
    end
  end

  sync do |state:, events:, replaying:|
    # Unless replaying?
    Sourced.config.backend.pubsub.publish('system', events.last.follow(System::Updated))
  end

  state do |id|
    { 
      id:, 
      fulfilled: false, 
      paid: false, 
      status: 'pending',
      sort: 0
    }
  end

  event Order::OrderFulfilled do |state, event|
    state[:fulfilled] = true
    state[:sort] = event.created_at.to_i
    check_deliverable(state)
  end

  event Order::PaymentConfirmed do |state, event|
    state[:paid] = true
    check_deliverable(state)
  end

  event Order::OrderDelivered do |state, event|
    state[:status] = 'delivered'
  end

  event Order::CustomerNameSet do |state, event|
    state[:customer_name] = event.payload.customer_name
  end

  reaction do |state, event|
    if state[:status] == 'ready'
      # Simulate slow command or grace period
      dispatch(Order::DeliverOrder).at(Time.now + 5)
    end
  end

  private def check_deliverable(state)
    state[:status] = 'ready' if state[:fulfilled] && state[:paid] 
  end
end
