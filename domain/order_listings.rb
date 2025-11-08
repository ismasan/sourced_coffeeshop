# frozen_string_literal: true

class OrderListings < Sourced::Projector::EventSourced
  DATA_DIR = './storage/orders'

  module System
    Updated = ::Sourced::Event.define('order_listings.system.updated')
  end

  # This block runs in a transaction when handling events
  # Just write a JSON representation of these listings
  sync do |state:, events:, replaying:|
    path = File.join(DATA_DIR, "#{state.id}.json")

    if state.status == 'deleted'
      File.unlink(path) if File.exist?(path)
    else
      FileUtils.mkdir_p(DATA_DIR)
      File.write(path, JSON.pretty_generate(state.to_h))
    end
  end

  sync do |state:, events:, replaying:|
    Sourced.config.backend.pubsub.publish('system', events.last.follow(System::Updated))
  end

  Items = Types::Hash[Types::Symbol.transform(String, &:to_s), Types::Hash.default { {} }]

  class Listing < Plumb::Types::Data
    attribute :id, String
    attribute :items, Items.default { {} }, writer: true
    attribute :status, Types::String.default('open'), writer: true
    attribute :seq, Types::Integer.default(0), writer: true
    attribute :members, Types::Array[String].default { [] }
    attribute :created_at, Types::Forms::Time, writer: true
    attribute :updated_at, Types::Forms::Time.nullable, writer: true
    attribute :payment_status, Types::String.default('--'), writer: true

    def total
      cents = items.values.sum do |item|
        item[:price].to_i * item[:quantity].to_i  
      end
      Money.from_cents(cents)
    end
  end

  # Let's give this class a repository interface
  # So that everything about this data is encapsuated here
  def self.all(limit: 100)
    list = Dir[File.join(DATA_DIR, '*.json')].map do |file|
      JSON.parse(File.read(file), symbolize_names: true)
    end.map { |r| Listing.parse(r) }.sort_by(&:created_at).reverse

    limit ? list.take(limit) : list
  end

  def self.placed
    all.select { |listing| listing.status == 'placed' }
  end

  state do |id|
    Listing.new(id:)
  end

  # Register all events and commands from Order
  # So that before_evolve runs before all Order messages
  evolve_all Order.handled_commands
  evolve_all Order

  before_evolve do |listing, event|
    listing.seq = event.seq
    username = event.metadata[:username]&.downcase
    listing.members << username if username && !listing.members.include?(username)
    listing.updated_at = event.created_at
  end

  event Order::Start do |listing, event|
    listing.created_at = event.created_at
  end

  event Order::Started do |listing, event|
    listing.created_at = event.created_at
  end

  event Order::ItemAdded do |listing, event|
    item_id = [event.payload.product_id, event.payload.variant_id].join('-')
    item = { price: event.payload.price, quantity: 0 }

    listing.items[item_id] ||= item
    listing.items[item_id][:quantity] += event.payload.quantity
  end

  event Order::ItemRemoved do |listing, event|
    listing.items.delete(event.payload.item_id)
  end

  event Order::ItemQuantityUpdated do |listing, event|
    listing.items[event.payload.item_id][:quantity] = event.payload.quantity
  end

  event Order::Canceled do |listing, event|
    listing.status = 'canceled'
  end

  event Order::Placed do |listing, event|
    listing.status = 'placed'
  end

  event Order::OrderFulfilled do |listing, event|
    listing.status = 'fulfilled'
  end

  event Order::ItemFulfillmentStarted do |listing, event|
    listing.items[event.payload.item_id][:status] = 'started'
  end

  event Order::ItemFulfilled do |listing, event|
    listing.items[event.payload.item_id][:status] = 'fulfilled'
  end

  event Order::PaymentStarted do |listing, event|
    listing.payment_status = 'processing'
  end

  event Order::PaymentConfirmed do |listing, event|
    listing.payment_status = 'paid'
  end

  event Order::OrderFulfilled do |listing, event|
    listing.status = 'fulfilled'
  end

  event Order::OrderDelivered do |listing, event|
    listing.status = 'delivered'
  end
end
