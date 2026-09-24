# frozen_string_literal: true

require 'spec_helper'

# A StateStored projector evolves the claimed batch on top of the stored row,
# so every message goes in `when` (the batch) and `then!` runs the sync block
# that writes the row.
RSpec.describe OrderListings do
  let(:order_id) { 'O1' }
  let(:latte) do
    { order_id:, product_id: 'latte', variant_id: 'small', product_name: 'Latte', variant_name: 'Small', quantity: 2, price: 480 }
  end

  def event(klass, **payload)
    klass.new(payload:, metadata: { username: 'Alice', producer: 'UI' })
  end

  it 'projects an open order with its items and staff' do
    with_reactor(OrderListings, order_id:)
      .when(event(Order::Started, order_id:))
      .when(event(Order::ItemAdded, **latte))
      .then!

    listing = OrderListings.find(order_id)
    expect(listing.status).to eq('open')
    expect(listing.step).to eq(2)
    expect(listing.members).to eq(['alice'])
    expect(listing.items['latte-small']).to include(quantity: 2, price: 480, status: 'pending')
    expect(listing.total).to eq(Money.from_cents(960))
    expect(listing.created_at).to be_a(Time)
  end

  it 'tracks status, fulfillment and payment' do
    with_reactor(OrderListings, order_id:)
      .when(event(Order::Started, order_id:))
      .when(event(Order::ItemAdded, **latte))
      .when(event(Order::Placed, order_id:))
      .when(event(Order::ItemFulfillmentStarted, order_id:, item_id: 'latte-small'))
      .when(event(Order::PaymentStarted, order_id:, payment_id: 'p1'))
      .then!

    expect(OrderListings.placed.map(&:id)).to eq([order_id])
    listing = OrderListings.find(order_id)
    expect(listing.items['latte-small'][:status]).to eq('started')
    expect(listing.payment_status).to eq('processing')
  end

  it 'evolves on top of the stored row' do
    with_reactor(OrderListings, order_id:)
      .when(event(Order::Started, order_id:))
      .when(event(Order::ItemAdded, **latte))
      .then!

    with_reactor(OrderListings, order_id:)
      .when(event(Order::Placed, order_id:))
      .then!

    listing = OrderListings.find(order_id)
    expect(listing.status).to eq('placed')
    expect(listing.step).to eq(3)
    expect(listing.items.keys).to eq(['latte-small'])
    expect(listing.members).to eq(['alice'])
  end

  it 'lists orders newest first' do
    with_reactor(OrderListings, order_id: 'O1')
      .when(Order::Started.new(payload: { order_id: 'O1' }, created_at: Time.now - 60))
      .then!
    with_reactor(OrderListings, order_id: 'O2')
      .when(Order::Started.new(payload: { order_id: 'O2' }))
      .then!

    expect(OrderListings.all.map(&:id)).to eq(%w[O2 O1])
  end
end
