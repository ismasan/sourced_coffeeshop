class Order < Sourced::Actor
  Start = Sourced::Command.define('orders.start')
  Started = Sourced::Event.define('orders.started')

  Item = Data.define(:id, :name, :price, :quantity) do
    def self.build(id:, name:, price: 0, quantity: 1)
      new(id:, name:, price:, quantity:)
    end

    def total = price * quantity
  end

  class State
    attr_reader :id, :items
    attr_accessor :status

    def initialize(id)
      @id = id
      @items = {}
      @status = :new
    end
  end

  state do |id|
    State.new(id)
  end

  command Start do |state, cmd|
    raise ArgumentError, 'Order already started' if state.status != :new

    event Started
  end

  event Started do |state, event|
    state.status = :open
  end
end
