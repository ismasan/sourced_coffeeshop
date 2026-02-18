class Order < Sourced::Actor
  module System
    Updated = ::Sourced::Event.define('orders.system.updated')
  end

  # This runs in the same transaction
  # as commiting new events to the backend
  # Here we publish an ephemeral event
  # so that the UI can react to it
  # In future, Sourced will have a special DSL for this
  sync do |state:, command:, events:|
    Sourced.config.pubsub.publish('system', command.follow(System::Updated))
  end

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

  ItemAdded = Sourced::Event.define('orders.item_added') do
    attribute :product_id, String
    attribute :variant_id, String
    attribute :product_name, String
    attribute :variant_name, String
    attribute :quantity, Integer
    attribute :price, Integer
  end

  RemoveItem = Sourced::Command.define('orders.remove_item') do
    attribute :item_id, Types::String.present
  end

  ItemRemoved = Sourced::Event.define('orders.item_removed') do
    attribute :item_id, String
  end

  UpdateItemQuantity = Sourced::Command.define('orders.update_item_quantity') do
    attribute :item_id, Types::String.present
    attribute :quantity, Types::Lax::Integer
  end

  ItemQuantityUpdated = Sourced::Event.define('orders.item_quantity_updated') do
    attribute :item_id, Types::String.present
    attribute :quantity, Types::Lax::Integer
  end

  Cancel = Sourced::Command.define('orders.cancel')
  Canceled = Sourced::Event.define('orders.canceled')

  Place = Sourced::Command.define('orders.place')
  Placed = Sourced::Event.define('orders.placed')

  SetCustomerName = Sourced::Command.define('orders.set_customer_name') do
    attribute :customer_name, Types::String.present
  end

  CustomerNameSet = Sourced::Event.define('orders.customer_name_set') do
    attribute :customer_name, String
  end

  # Item fulfillment
  StartItemFulfillment = Sourced::Command.define('orders.start_item_fulfillment') do
    attribute :item_id, Types::String.present
  end

  ItemFulfillmentStarted = Sourced::Event.define('orders.item_fulfillment_started') do
    attribute :item_id, String
  end

  FulfillItem = Sourced::Command.define('orders.fulfill_item') do
    attribute :item_id, Types::String.present
  end

  ItemFulfilled = Sourced::Event.define('orders.item_fulfilled') do
    attribute :item_id, String
  end

  FulfillOrder = Sourced::Command.define('orders.fulfill_order')
  OrderFulfilled = Sourced::Event.define('orders.order_fulfilled')

  StartPayment = Sourced::Command.define('orders.start_payment')
  PaymentStarted = Sourced::Event.define('orders.payment_started') do
    attribute :payment_id, Types::String
  end

  ConfirmPayment = Sourced::Command.define('orders.confirm_payment') do
    attribute :payment_id, Types::String
  end
  PaymentConfirmed = Sourced::Event.define('orders.payment_confirmed')

  DeliverOrder = Sourced::Command.define('orders.deliver_order')
  OrderDelivered = Sourced::Event.define('orders.order_delivered')

  class State
    VAT = 0.135

    Item = Struct.new(:product_id, :variant_id, :product_name, :variant_name, :price, :quantity, :status, keyword_init: true) do
      def total = price * quantity
      def id = [product_id, variant_id].join('-')
      def full_name = [product_name, variant_name].join(' - ')

      def pending? = status == :pending
      def started? = status == :started
      def fulfilled? = status == :fulfilled

      def start!
        self.status = :started
      end

      def fulfill!
        self.status = :fulfilled
      end

      def self.build(product_id:, variant_id:, product_name:, variant_name:, quantity: 1, price: 0, status: :pending)
        new(
          product_id:,
          variant_id:,
          product_name:,
          variant_name:,
          quantity:,
          price:,
          status:,
        )
      end
    end

    Payment = Struct.new(:id, :status) do
      def pending? = status == :pending
      def started? = status == :started
      def confirmed? = status == :confirmed
    end

    attr_reader :id, :items, :payment
    attr_accessor :status, :customer_name, :created_at, :created_by

    def initialize(id)
      @id = id
      @items = {}
      @status = :new
      @customer_name = nil
      @created_at = nil
      @created_by = nil
      @payment = Payment.new(nil, :pending)
    end

    def subtotal = items.values.sum(Money.zero, &:total)
    def tax = subtotal * VAT
    def total = subtotal + tax

    def open? = status == :open
    def placed? = status == :placed

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
    state.created_at = event.created_at
    state.created_by = event.metadata[:username]
  end

  command AddItem do |state, cmd|
    return unless state.open?

    event ItemAdded, cmd.payload
  end

  event ItemAdded do |state, event|
    state.add_item(**event.payload)
  end

  command RemoveItem do |state, cmd|
    return unless state.open? && state.items[cmd.payload.item_id]

    event ItemRemoved, cmd.payload
  end

  event ItemRemoved do |state, event|
    state.items.delete(event.payload.item_id)
  end

  command UpdateItemQuantity do |state, cmd|
    return unless state.open? && state.items[cmd.payload.item_id]

    event ItemQuantityUpdated, cmd.payload
  end

  event ItemQuantityUpdated do |state, event|
    item = state.items[event.payload.item_id]
    item.quantity = event.payload.quantity
  end

  command Cancel do |state, cmd|
    return unless state.open?

    event Canceled
  end

  event Canceled do |state, event|
    state.status = :canceled
  end

  command Place do |state, cmd|
    return unless state.open?

    event Placed, cmd.payload
  end

  event Placed do |state, event|
    state.status = :placed
  end

  command SetCustomerName do |state, cmd|
    return unless state.placed?

    event CustomerNameSet, cmd.payload
  end

  event CustomerNameSet do |state, event|
    state.customer_name = event.payload.customer_name
  end

  command StartItemFulfillment do |state, cmd|
    item = state.items[cmd.payload.item_id]
    return unless item && item.pending?

    event ItemFulfillmentStarted, cmd.payload
  end

  event ItemFulfillmentStarted do |state, event|
    item = state.items[event.payload.item_id]
    item.start!
  end

  command FulfillItem do |state, cmd|
    item = state.items[cmd.payload.item_id]
    return unless item && item.started?

    event ItemFulfilled, cmd.payload
  end

  event ItemFulfilled do |state, event|
    item = state.items[event.payload.item_id]
    item.fulfill!
  end

  reaction ItemFulfilled do |state, event|
    if state.items.values.all?(&:fulfilled?)
      dispatch(FulfillOrder)
    end
  end

  command FulfillOrder do |state, cmd|
    if state.items.values.all?(&:fulfilled?)
      event OrderFulfilled
    end
  end

  event OrderFulfilled do |state, event|
    state.status = :fulfilled
  end

  command StartPayment do |state, cmd|
    return if state.open? || state.payment.status != :pending

    event PaymentStarted, payment_id: ['payment', state.id].join('-')
  end

  event PaymentStarted do |state, event|
    state.payment.status = :started
    state.payment.id = event.payload.payment_id
  end

  reaction PaymentStarted do |state, event|
    dispatch(
      Payment::Start, 
      order_id: state.id, 
      amount: state.total.cents
    ).to(state.payment.id)
  end

  command ConfirmPayment do |state, cmd|
    return unless state.payment.status == :started

    event PaymentConfirmed
  end

  event PaymentConfirmed do |state, event|
    state.payment.status = :confirmed
  end

      # def fulfilled? = status == :fulfilled
  command DeliverOrder do |state, cmd|
    # return unless state.fulfilled?

    event OrderDelivered
  end

  event OrderDelivered do |state, event|
    state.status = :delivered
  end
end
