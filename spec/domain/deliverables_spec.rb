# frozen_string_literal: true

require 'spec_helper'

# An EventSourced projector rebuilds its state from the partition's full
# history, which at runtime includes the claimed batch. So the triggering
# event goes in both `given` (history) and `when` (the batch).
RSpec.describe Deliverables do
  let(:order_id) { 'O1' }
  let(:paid) { Order::PaymentConfirmed.new(payload: { order_id:, payment_id: 'p1' }) }
  let(:delivered) { Order::OrderDelivered.new(payload: { order_id: }) }

  it 'lists an order once it is fulfilled and paid, and schedules its delivery' do
    with_reactor(Deliverables, order_id:)
      .given(Order::CustomerNameSet, order_id:, customer_name: 'Ada')
      .and(Order::OrderFulfilled, order_id:)
      .and(paid)
      .when(paid)
      .then! do |result|
        rows = Deliverables.all
        expect(rows.map { |r| r[:order_id] }).to eq([order_id])
        expect(rows.first[:customer_name]).to eq('Ada')

        deliver = result.messages.first
        expect(deliver).to be_a(Order::DeliverOrder)
        expect(deliver.payload.order_id).to eq(order_id)
        expect(deliver.created_at).to be > Time.now + (Deliverables::AUTO_DELIVER_AFTER - 1)
      end
  end

  it 'schedules the delivery once, from the event that completed the order' do
    fulfilled = Order::OrderFulfilled.new(payload: { order_id: })

    with_reactor(Deliverables, order_id:)
      .given(paid)
      .and(fulfilled)
      .when(paid)
      .when(fulfilled)
      .then! do |result|
        expect(result.messages.size).to eq(1)
        expect(result.messages.first).to be_a(Order::DeliverOrder)
      end
  end

  it 'does not list an order that is only fulfilled' do
    fulfilled = Order::OrderFulfilled.new(payload: { order_id: })

    with_reactor(Deliverables, order_id:)
      .given(fulfilled)
      .when(fulfilled)
      .then! do |result|
        expect(Deliverables.all).to be_empty
        expect(result.messages).to be_empty
      end
  end

  it 'removes a delivered order' do
    with_reactor(Deliverables, order_id:)
      .given(Order::OrderFulfilled, order_id:)
      .and(paid)
      .and(delivered)
      .when(delivered)
      .then! do |result|
        expect(Deliverables.all).to be_empty
        expect(result.messages).to be_empty
      end
  end
end
