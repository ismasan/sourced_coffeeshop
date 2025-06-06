class OrderListings < Sourced::Projector::EventSourced
  DATA_DIR = './storage/orders'

  # This block runs in a transaction when handling events
  # Just write a JSON representation of these listings
  sync do |state, _command, events|
    path = File.join(DATA_DIR, "#{state[:id]}.json")

    if state[:status] == 'deleted'
      File.unlink(path) if File.exist?(path)
    else
      FileUtils.mkdir_p(DATA_DIR)
      File.write(path, JSON.pretty_generate(state))
    end
  end

  # Let's give this class a repository interface
  # So that everything about this data is encapsuated here
  def self.all(limit: 100)
    list = Dir[File.join(DATA_DIR, '*.json')].map do |file|
      JSON.parse(File.read(file), symbolize_names: true)
    end.sort_by { |row| row[:created_at_int] }.reverse

    limit ? list.take(limit) : list
  end

  state do |id|
    { 
      id:, 
      total: 0, 
      status: 'open',
      seq: 0,
      members: [],
      created_at_int: 0,
      updated_at: nil
    }
  end

  # Register all events and commands from Order
  # So that before_evolve runs before all Order messages
  evolve_all Order.handled_commands
  evolve_all Order

  before_evolve do |state, event|
    state[:seq] = event.seq
    username = event.metadata[:username]&.downcase
    state[:members] << username if username && !state[:members].include?(username)
    state[:updated_at] = event.created_at
  end

  event Order::Started do |state, event|
    state[:created_at_int] = event.created_at.to_i
  end
end
