# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Order do
  let(:order_id) { 'O1' }
  let(:latte) do
    { order_id:, product_id: 'latte', variant_id: 'small', product_name: 'Latte', variant_name: 'Small', quantity: 1, price: 480 }
  end
  let(:espresso) do
    { order_id:, product_id: 'espresso', variant_id: 'single', product_name: 'Espresso', variant_name: 'Single', quantity: 2, price: 280 }
  end

  def started
    with_reactor(Order, order_id:).given(Order::Started, order_id:)
  end

  def placed
    started
      .and(Order::ItemAdded, **latte)
      .and(Order::ItemAdded, **espresso)
      .and(Order::Placed, order_id:)
  end

  describe Order::Start do
    it 'starts a new order' do
      with_reactor(Order, order_id:)
        .when(Order::Start, order_id:)
        .then(Order::Started, order_id:)
    end

    it 'is a no-op for an order that already started' do
      started.when(Order::Start, order_id:).then([])
    end
  end

  describe 'items' do
    it 'adds items to an open order' do
      started
        .when(Order::AddItem, **latte)
        .then(Order::ItemAdded, **latte)
    end

    it 'merges quantities of the same item' do
      started
        .and(Order::ItemAdded, **latte)
        .and(Order::ItemAdded, **latte.merge(quantity: 2))
        .then do |result|
          item = result.state.items['latte-small']
          expect(item.quantity).to eq(3)
          expect(result.state.subtotal).to eq(Money.from_cents(480 * 3))
        end
    end

    it 'does not add items to a placed order' do
      placed.when(Order::AddItem, **latte).then([])
    end

    it 'updates the quantity of an existing item' do
      started
        .and(Order::ItemAdded, **latte)
        .when(Order::UpdateItemQuantity, order_id:, item_id: 'latte-small', quantity: 4)
        .then(Order::ItemQuantityUpdated, order_id:, item_id: 'latte-small', quantity: 4)
    end

    it 'removes an existing item' do
      started
        .and(Order::ItemAdded, **latte)
        .when(Order::RemoveItem, order_id:, item_id: 'latte-small')
        .then(Order::ItemRemoved, order_id:, item_id: 'latte-small')
    end

    it 'ignores updates and removals of unknown items' do
      started
        .and(Order::ItemAdded, **latte)
        .when(Order::UpdateItemQuantity, order_id:, item_id: 'nope', quantity: 4)
        .when(Order::RemoveItem, order_id:, item_id: 'nope')
        .then([])
    end
  end

  describe 'placing and canceling' do
    it 'places an open order with items' do
      started
        .and(Order::ItemAdded, **latte)
        .when(Order::Place, order_id:)
        .then(Order::Placed, order_id:)
    end

    it 'does not place an empty order' do
      started.when(Order::Place, order_id:).then([])
    end

    it 'cancels an open order' do
      started.when(Order::Cancel, order_id:).then(Order::Canceled, order_id:)
    end

    it 'does not cancel a placed order' do
      placed.when(Order::Cancel, order_id:).then([])
    end

    it 'sets the customer name once placed' do
      placed
        .when(Order::SetCustomerName, order_id:, customer_name: 'Ada')
        .then(Order::CustomerNameSet, order_id:, customer_name: 'Ada')
    end
  end

  describe 'fulfillment' do
    # Two commands in one batch: the decider applies the first command's
    # event to its in-memory state before deciding the second.
    it 'starts and finishes an item within one batch' do
      placed
        .when(Order::StartItemFulfillment, order_id:, item_id: 'latte-small')
        .when(Order::FulfillItem, order_id:, item_id: 'latte-small')
        .then(
          Order::ItemFulfillmentStarted.new(payload: { order_id:, item_id: 'latte-small' }),
          Order::ItemFulfilled.new(payload: { order_id:, item_id: 'latte-small' })
        )
    end

    it 'cannot finish an item that was not started' do
      placed.when(Order::FulfillItem, order_id:, item_id: 'latte-small').then([])
    end

    it 'fulfills the order once the last item is fulfilled' do
      placed
        .and(Order::ItemFulfillmentStarted, order_id:, item_id: 'latte-small')
        .and(Order::ItemFulfilled, order_id:, item_id: 'latte-small')
        .and(Order::ItemFulfillmentStarted, order_id:, item_id: 'espresso-single')
        .when(Order::ItemFulfilled, order_id:, item_id: 'espresso-single')
        .then(Order::FulfillOrder, order_id:)
    end

    it 'does not fulfill the order while items are pending' do
      placed
        .and(Order::ItemFulfillmentStarted, order_id:, item_id: 'latte-small')
        .when(Order::ItemFulfilled, order_id:, item_id: 'latte-small')
        .then([])
    end
  end

  describe 'payment' do
    it 'starts a payment for a placed order' do
      placed
        .when(Order::StartPayment, order_id:)
        .then(Order::PaymentStarted, order_id:, payment_id: 'payment-O1')
    end

    it 'does not start a payment for an open order' do
      started.when(Order::StartPayment, order_id:).then([])
    end

    it 'does not start a second payment' do
      placed
        .and(Order::PaymentStarted, order_id:, payment_id: 'payment-O1')
        .when(Order::StartPayment, order_id:)
        .then([])
    end

    it 'hands over to Payment with the order total once the payment starts' do
      placed
        .when(Order::PaymentStarted, order_id:, payment_id: 'payment-O1')
        .then(Payment::Start, payment_id: 'payment-O1', order_id:, amount: 1180) # (480 + 2 * 280) * 1.135
    end

    it 'confirms the started payment' do
      placed
        .and(Order::PaymentStarted, order_id:, payment_id: 'payment-O1')
        .when(Order::ConfirmPayment, order_id:, payment_id: 'payment-O1')
        .then(Order::PaymentConfirmed, order_id:, payment_id: 'payment-O1')
    end

    it 'ignores a confirmation for a different payment' do
      placed
        .and(Order::PaymentStarted, order_id:, payment_id: 'payment-O1')
        .when(Order::ConfirmPayment, order_id:, payment_id: 'payment-other')
        .then([])
    end
  end

  describe Order::DeliverOrder do
    it 'delivers a fulfilled and paid order' do
      placed
        .and(Order::OrderFulfilled, order_id:)
        .and(Order::PaymentStarted, order_id:, payment_id: 'payment-O1')
        .and(Order::PaymentConfirmed, order_id:, payment_id: 'payment-O1')
        .when(Order::DeliverOrder, order_id:)
        .then(Order::OrderDelivered, order_id:)
    end

    it 'does not deliver an unpaid order' do
      placed
        .and(Order::OrderFulfilled, order_id:)
        .when(Order::DeliverOrder, order_id:)
        .then([])
    end

    it 'does not deliver a paid order that is not fulfilled' do
      placed
        .and(Order::PaymentStarted, order_id:, payment_id: 'payment-O1')
        .and(Order::PaymentConfirmed, order_id:, payment_id: 'payment-O1')
        .when(Order::DeliverOrder, order_id:)
        .then([])
    end
  end
end
