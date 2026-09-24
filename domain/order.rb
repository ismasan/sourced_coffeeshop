# frozen_string_literal: true

require 'securerandom'

# The Order decider: the write model for a single coffee shop order.
#
# Every command and event carries an +order_id+, which is the partition key.
# Sourced reads the partition (all messages sharing that order_id) to rebuild
# +State+ before handling each command, and serialises commands per partition.
class Order < Sourced::Decider
  consumer_group 'orders'
  partition_by :order_id

  VAT = 0.135

  # Human-friendly order ids, ex. "O20260924-8F443625"
  def self.new_id
    "O#{Time.now.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  # Commands and events that belong to one order's stream: used to filter
  # the partition read that drives the order page's history sidebar.
  def self.display_types
    (handled_commands + handled_messages_for_evolve).uniq.map(&:type)
  end

  # ---- Commands ----

  Start = Sourced::Command.define('orders.start') do
    attribute :order_id, Types::String.present
  end

  AddItem = Sourced::Command.define('orders.add_item') do
    attribute :order_id, Types::String.present
    attribute :product_id, Types::String.present
    attribute :variant_id, Types::String.present
    attribute :product_name, Types::String.present
    attribute :variant_name, Types::String.present
    attribute :quantity, Types::Integer.default(1)
    attribute :price, Types::Integer.default(0)
  end

  RemoveItem = Sourced::Command.define('orders.remove_item') do
    attribute :order_id, Types::String.present
    attribute :item_id, Types::String.present
  end

  UpdateItemQuantity = Sourced::Command.define('orders.update_item_quantity') do
    attribute :order_id, Types::String.present
    attribute :item_id, Types::String.present
    attribute :quantity, Integer
  end

  Cancel = Sourced::Command.define('orders.cancel') do
    attribute :order_id, Types::String.present
  end

  Place = Sourced::Command.define('orders.place') do
    attribute :order_id, Types::String.present
  end

  SetCustomerName = Sourced::Command.define('orders.set_customer_name') do
    attribute :order_id, Types::String.present
    attribute :customer_name, Types::String.present
  end

  StartItemFulfillment = Sourced::Command.define('orders.start_item_fulfillment') do
    attribute :order_id, Types::String.present
    attribute :item_id, Types::String.present
  end

  FulfillItem = Sourced::Command.define('orders.fulfill_item') do
    attribute :order_id, Types::String.present
    attribute :item_id, Types::String.present
  end

  FulfillOrder = Sourced::Command.define('orders.fulfill_order') do
    attribute :order_id, Types::String.present
  end

  StartPayment = Sourced::Command.define('orders.start_payment') do
    attribute :order_id, Types::String.present
  end

  ConfirmPayment = Sourced::Command.define('orders.confirm_payment') do
    attribute :order_id, Types::String.present
    attribute :payment_id, Types::String.present
  end

  DeliverOrder = Sourced::Command.define('orders.deliver_order') do
    attribute :order_id, Types::String.present
  end

  # ---- Events ----

  Started = Sourced::Event.define('orders.started') do
    attribute :order_id, String
  end

  ItemAdded = Sourced::Event.define('orders.item_added') do
    attribute :order_id, String
    attribute :product_id, String
    attribute :variant_id, String
    attribute :product_name, String
    attribute :variant_name, String
    attribute :quantity, Integer
    attribute :price, Integer
  end

  ItemRemoved = Sourced::Event.define('orders.item_removed') do
    attribute :order_id, String
    attribute :item_id, String
  end

  ItemQuantityUpdated = Sourced::Event.define('orders.item_quantity_updated') do
    attribute :order_id, String
    attribute :item_id, String
    attribute :quantity, Integer
  end

  Canceled = Sourced::Event.define('orders.canceled') do
    attribute :order_id, String
  end

  Placed = Sourced::Event.define('orders.placed') do
    attribute :order_id, String
  end

  CustomerNameSet = Sourced::Event.define('orders.customer_name_set') do
    attribute :order_id, String
    attribute :customer_name, String
  end

  ItemFulfillmentStarted = Sourced::Event.define('orders.item_fulfillment_started') do
    attribute :order_id, String
    attribute :item_id, String
  end

  ItemFulfilled = Sourced::Event.define('orders.item_fulfilled') do
    attribute :order_id, String
    attribute :item_id, String
  end

  OrderFulfilled = Sourced::Event.define('orders.order_fulfilled') do
    attribute :order_id, String
  end

  PaymentStarted = Sourced::Event.define('orders.payment_started') do
    attribute :order_id, String
    attribute :payment_id, String
  end

  PaymentConfirmed = Sourced::Event.define('orders.payment_confirmed') do
    attribute :order_id, String
    attribute :payment_id, String
  end

  OrderDelivered = Sourced::Event.define('orders.order_delivered') do
    attribute :order_id, String
  end

  # ---- State ----

  class State
    Item = Struct.new(:product_id, :variant_id, :product_name, :variant_name, :price, :quantity, :status, keyword_init: true) do
      def total = price * quantity
      def id = [product_id, variant_id].join('-')
      def full_name = [product_name, variant_name].join(' - ')

      def pending? = status == :pending
      def started? = status == :started
      def fulfilled? = status == :fulfilled

      def start! = self.status = :started
      def fulfill! = self.status = :fulfilled

      def self.build(product_id:, variant_id:, product_name:, variant_name:, quantity: 1, price: 0, status: :pending)
        new(product_id:, variant_id:, product_name:, variant_name:, quantity:, price:, status:)
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

    def new? = status == :new
    def open? = status == :open
    def placed? = status == :placed
    def fulfilled? = status == :fulfilled
    def delivered? = status == :delivered
    def canceled? = status == :canceled
    def paid? = payment.confirmed?
    # Ready to hand over to the customer: everything made, and paid for.
    def deliverable? = fulfilled? && paid?

    def add_item(price:, **kargs)
      price = Money.from_cents(price) if price.is_a?(Integer)

      item = Item.build(price:, **kargs)
      if (existing = @items[item.id])
        item.quantity += existing.quantity
      end
      @items[item.id] = item
    end
  end

  state do |values|
    State.new(values[:order_id])
  end

  # ---- Command handlers ----
  #
  # Commands that don't apply to the current state are silent no-ops rather
  # than raises: Sourced's default error strategy stops the whole consumer
  # group when a handler raises, which would halt every order over one stale
  # click.

  command Start do |state, cmd|
    return unless state.new?

    event Started, order_id: cmd.payload.order_id
  end

  evolve Started do |state, event|
    state.status = :open
    state.created_at = event.created_at
    state.created_by = event.metadata[:username]
  end

  command AddItem do |state, cmd|
    return unless state.open?

    event ItemAdded, cmd.payload.to_h
  end

  evolve ItemAdded do |state, event|
    state.add_item(**event.payload.to_h.except(:order_id))
  end

  command RemoveItem do |state, cmd|
    return unless state.open? && state.items[cmd.payload.item_id]

    event ItemRemoved, cmd.payload.to_h
  end

  evolve ItemRemoved do |state, event|
    state.items.delete(event.payload.item_id)
  end

  command UpdateItemQuantity do |state, cmd|
    return unless state.open? && state.items[cmd.payload.item_id]
    return unless cmd.payload.quantity.positive?

    event ItemQuantityUpdated, cmd.payload.to_h
  end

  evolve ItemQuantityUpdated do |state, event|
    item = state.items[event.payload.item_id]
    item.quantity = event.payload.quantity if item
  end

  command Cancel do |state, cmd|
    return unless state.open?

    event Canceled, order_id: cmd.payload.order_id
  end

  evolve Canceled do |state, _event|
    state.status = :canceled
  end

  command Place do |state, cmd|
    return unless state.open? && state.items.any?

    event Placed, order_id: cmd.payload.order_id
  end

  evolve Placed do |state, _event|
    state.status = :placed
  end

  command SetCustomerName do |state, cmd|
    return unless state.placed?

    event CustomerNameSet, cmd.payload.to_h
  end

  evolve CustomerNameSet do |state, event|
    state.customer_name = event.payload.customer_name
  end

  command StartItemFulfillment do |state, cmd|
    item = state.items[cmd.payload.item_id]
    return unless state.placed? && item&.pending?

    event ItemFulfillmentStarted, cmd.payload.to_h
  end

  evolve ItemFulfillmentStarted do |state, event|
    state.items[event.payload.item_id]&.start!
  end

  command FulfillItem do |state, cmd|
    item = state.items[cmd.payload.item_id]
    return unless item&.started?

    event ItemFulfilled, cmd.payload.to_h
  end

  evolve ItemFulfilled do |state, event|
    state.items[event.payload.item_id]&.fulfill!
  end

  # Automation: once the last item is fulfilled, fulfill the whole order.
  reaction ItemFulfilled do |state, event|
    if state.placed? && state.items.values.all?(&:fulfilled?)
      dispatch FulfillOrder, order_id: event.payload.order_id
    end
  end

  command FulfillOrder do |state, cmd|
    return unless state.placed? && state.items.values.all?(&:fulfilled?)

    event OrderFulfilled, order_id: cmd.payload.order_id
  end

  evolve OrderFulfilled do |state, _event|
    state.status = :fulfilled
  end

  command StartPayment do |state, cmd|
    return if state.new? || state.open? || state.canceled?
    return unless state.payment.pending?

    event PaymentStarted, order_id: cmd.payload.order_id, payment_id: "payment-#{state.id}"
  end

  evolve PaymentStarted do |state, event|
    state.payment.status = :started
    state.payment.id = event.payload.payment_id
  end

  # Automation: hand over to the Payment decider, which talks to the
  # (simulated) payment provider and reports back with ConfirmPayment.
  reaction PaymentStarted do |state, event|
    dispatch Payment::Start,
      payment_id: event.payload.payment_id,
      order_id: event.payload.order_id,
      amount: state.total.cents
  end

  command ConfirmPayment do |state, cmd|
    return unless state.payment.started? && state.payment.id == cmd.payload.payment_id

    event PaymentConfirmed, cmd.payload.to_h
  end

  evolve PaymentConfirmed do |state, _event|
    state.payment.status = :confirmed
  end

  command DeliverOrder do |state, cmd|
    return unless state.deliverable?

    event OrderDelivered, order_id: cmd.payload.order_id
  end

  evolve OrderDelivered do |state, _event|
    state.status = :delivered
  end
end
