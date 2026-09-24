# frozen_string_literal: true

require 'json'
require 'time'

# Cross-order read model powering the home, cashier and barista tables:
# one row per order in the +orders+ table, upserted as the order's events
# arrive. A +Projected+ signal (attribute: order_id) is auto-generated from
# +partition_by+ and published by Sidereal::Integrations::Sourced after each
# committed batch, which is what re-renders the pages listing orders.
class OrderListings < Sourced::Projector::StateStored
  consumer_group 'order_listings'
  partition_by :order_id

  TABLE = :orders

  # Read-side value object over an +orders+ row.
  Listing = Data.define(:order_id, :status, :payment_status, :customer_name, :items, :members, :step, :created_at, :updated_at) do
    def self.from_row(row)
      new(**OrderListings.decode_row(row))
    end

    def id = order_id

    def total
      Money.from_cents(items.values.sum { |item| item[:price].to_i * item[:quantity].to_i })
    end
  end

  BLANK = {
    order_id: nil,
    status: 'new',
    payment_status: '--',
    customer_name: nil,
    items: {},
    members: [],
    step: 0,
    created_at: nil,
    updated_at: nil
  }.freeze

  # ---- Row (de)serialization: items and members live in JSON columns ----

  def self.decode_row(row)
    row.merge(
      items: JSON.parse(row[:items] || '{}', symbolize_names: true).transform_keys(&:to_s),
      members: JSON.parse(row[:members] || '[]'),
      created_at: row[:created_at] && Time.iso8601(row[:created_at]),
      updated_at: row[:updated_at] && Time.iso8601(row[:updated_at])
    )
  end

  def self.encode_row(state)
    state.merge(
      items: JSON.generate(state[:items]),
      members: JSON.generate(state[:members])
    )
  end

  # ---- Class-level queries ----

  def self.dataset = Sourced.store.db[TABLE]

  def self.all(limit: 100)
    dataset.order(Sequel.desc(:created_at)).limit(limit).map { |row| Listing.from_row(row) }
  end

  def self.placed
    dataset.where(status: 'placed').order(:created_at).map { |row| Listing.from_row(row) }
  end

  def self.find(order_id)
    row = dataset.where(order_id:).first
    row && Listing.from_row(row)
  end

  def self.on_reset
    dataset.delete
  end

  # ---- Projection ----

  state do |values|
    row = self.class.dataset.where(order_id: values[:order_id]).first
    if row
      self.class.decode_row(row).tap do |st|
        st[:created_at] = st[:created_at]&.iso8601
        st[:updated_at] = st[:updated_at]&.iso8601
      end
    else
      BLANK.merge(order_id: values[:order_id], items: {}, members: [])
    end
  end

  # Every order event bumps the step counter, the updated_at timestamp and
  # the list of staff (usernames stamped on command metadata by the UI)
  # who touched the order, then applies the event-specific change.
  def self.project(*event_classes, &block)
    event_classes.each do |event_class|
      evolve(event_class) do |state, event|
        state[:step] += 1
        state[:updated_at] = event.created_at.iso8601
        username = event.metadata[:username]&.downcase
        state[:members] << username if username && !state[:members].include?(username)
        instance_exec(state, event, &block) if block
      end
    end
  end

  project Order::Started do |state, event|
    state[:status] = 'open'
    state[:created_at] = event.created_at.iso8601
  end

  project Order::ItemAdded do |state, event|
    item_id = [event.payload.product_id, event.payload.variant_id].join('-')
    item = state[:items][item_id] ||= {
      name: [event.payload.product_name, event.payload.variant_name].join(' - '),
      price: event.payload.price,
      quantity: 0,
      status: 'pending'
    }
    item[:quantity] += event.payload.quantity
  end

  project Order::ItemRemoved do |state, event|
    state[:items].delete(event.payload.item_id)
  end

  project Order::ItemQuantityUpdated do |state, event|
    item = state[:items][event.payload.item_id]
    item[:quantity] = event.payload.quantity if item
  end

  project Order::Canceled do |state, _event|
    state[:status] = 'canceled'
  end

  project Order::Placed do |state, _event|
    state[:status] = 'placed'
  end

  project Order::CustomerNameSet do |state, event|
    state[:customer_name] = event.payload.customer_name
  end

  project Order::ItemFulfillmentStarted do |state, event|
    item = state[:items][event.payload.item_id]
    item[:status] = 'started' if item
  end

  project Order::ItemFulfilled do |state, event|
    item = state[:items][event.payload.item_id]
    item[:status] = 'fulfilled' if item
  end

  project Order::OrderFulfilled do |state, _event|
    state[:status] = 'fulfilled'
  end

  project Order::PaymentStarted do |state, _event|
    state[:payment_status] = 'processing'
  end

  project Order::PaymentConfirmed do |state, _event|
    state[:payment_status] = 'paid'
  end

  project Order::OrderDelivered do |state, _event|
    state[:status] = 'delivered'
  end

  # Runs inside the store transaction: the row commits with the offset.
  sync do |state:, **|
    next unless state[:order_id]

    self.class.dataset.insert_conflict(:replace).insert(self.class.encode_row(state))
  end
end
