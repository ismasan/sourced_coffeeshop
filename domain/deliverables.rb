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
  # Just write a JSON representation of these listings
  sync do |listing, _command, events|
    path = File.join(DATA_DIR, "#{listing[:id]}.json")

    FileUtils.mkdir_p(DATA_DIR)

    if listing[:status] == 'ready'
      File.write(path, JSON.pretty_generate(listing.to_h))
    elsif listing[:status] == 'delivered' && File.exist?(path)
      File.unlink(path)
    end
  end

  sync do |list, _command, events|
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
    state[:sort] = event.created_at.to_i
    state[:fulfilled] = true
    check_deliverable(state)
  end

  event Order::PaymentConfirmed do |state, event|
    state[:paid] = true
    check_deliverable(state)
  end

  event Order::OrderDelivered do |state, event|
    state[:status] = 'delivered'
  end

  reaction do |state, event|
    if state[:status] == 'ready'
      stream_for(event).command(Order::DeliverOrder, deliverable_id: state[:id]) do |cmd|
        cmd.delay Time.now + 5 # Simulate a delay for delivery
      end
    end
  end

  private def check_deliverable(state)
    state[:status] = 'ready' if state[:fulfilled] && state[:paid] 
  end
end
