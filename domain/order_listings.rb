# frozen_string_literal: true

class OrderListings < Sourced::Projector::EventSourced
  DATA_DIR = './storage/orders'

  # This block runs in a transaction when handling events
  # Just write a JSON representation of these listings
  sync do |listing, _command, events|
    path = File.join(DATA_DIR, "#{listing.id}.json")

    if listing.status == 'deleted'
      File.unlink(path) if File.exist?(path)
    else
      FileUtils.mkdir_p(DATA_DIR)
      File.write(path, JSON.pretty_generate(listing.to_h))
    end
  end

  class Listing < Plumb::Types::Data
    attribute :id, String
    attribute :total, Plumb::Types::Integer.default(0), writer: true
    attribute :status, Plumb::Types::String.default('open'), writer: true
    attribute :seq, Plumb::Types::Integer.default(0), writer: true
    attribute :members, Plumb::Types::Array[String].default { [] }
    attribute :created_at, Plumb::Types::Forms::Time.nullable, writer: true
    attribute :updated_at, Plumb::Types::Forms::Time.nullable, writer: true
  end

  # Let's give this class a repository interface
  # So that everything about this data is encapsuated here
  def self.all(limit: 100)
    list = Dir[File.join(DATA_DIR, '*.json')].map do |file|
      JSON.parse(File.read(file), symbolize_names: true)
    end.map { |r| Listing.parse(r) }.sort_by(&:created_at).reverse

    limit ? list.take(limit) : list
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

  event Order::Started do |listing, event|
    listing.created_at = event.created_at
  end
end
