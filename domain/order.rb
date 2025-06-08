class Order < Sourced::Actor
  Start = Sourced::Command.define('orders.start')
  Started = Sourced::Event.define('orders.started')

  AddItem = Sourced::Command.define('orders.add_item') do
    attribute :product_id, Types::String.present
    attribute :variant_id, Types::String.present
    attribute :product_name, Types::String.present
    attribute :variant_name, Types::String.present
    attribute :quantity, Types::Lax::Integer.default(1)
    attribute :price, Types::Lax::Integer.default(0)
  end

  ItemAdded = Sourced::Command.define('orders.item_added') do
    attribute :product_id, String
    attribute :variant_id, String
    attribute :product_name, String
    attribute :variant_name, String
    attribute :quantity, Integer
    attribute :price, Integer
  end

  class State
    VAT = 0.135

    Item = Struct.new(:product_id, :variant_id, :product_name, :variant_name, :price, :quantity, keyword_init: true) do
      def total = price * quantity
      def id = [product_id, variant_id].join('-')

      def self.build(product_id:, variant_id:, product_name:, variant_name:, quantity: 1, price: 0)
        new(
          product_id: product_id,
          variant_id: variant_id,
          product_name: product_name,
          variant_name: variant_name,
          quantity: quantity,
          price: price
        )
      end
    end

    attr_reader :id, :items
    attr_accessor :status

    def initialize(id)
      @id = id
      @items = {}
      @status = :new
    end

    def subtotal = items.values.sum(&:total)
    def tax = subtotal * VAT
    def total = subtotal + tax

    def open? = status == :open

    def add_item(price:, **kargs)
      price = Money.from_cents(price) if price.is_a?(Integer)

      item = Item.build(price:, **kargs)
      if (it = @items[item.id])
        item.quantity += it.quantity
      end
      @items[item.id] = item
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

  command AddItem do |state, cmd|
    raise ArgumentError, 'Order not open' unless state.open?

    event ItemAdded, cmd.payload
  end

  event ItemAdded do |state, event|
    state.add_item(**event.payload)
  end
end
