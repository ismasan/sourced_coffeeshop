class PaymentListings < Sourced::Projector::EventSourced
  DATA_DIR = './storage/payments'

  module System
    Updated = ::Sourced::Event.define('payment_listings.system.updated')
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
    File.write(path, JSON.pretty_generate(listing.to_h))
  end

  sync do |list, _command, events|
    Sourced.config.backend.pubsub.publish('system', events.last.follow(System::Updated))
  end

  state do |id|
    { id:, status: 'started', created_at: nil, sort: 0, order_id: nil, amount: 0 }
  end

  event Payment::Started do |listing, event|
    listing[:created_at] = event.created_at.to_s
    listing[:sort] = event.created_at.to_i
    listing[:order_id] = event.payload.order_id
    listing[:amount] = event.payload.amount
  end

  event Payment::Confirmed do |listing, event|
    listing[:status] = 'confirmed'
  end
end
