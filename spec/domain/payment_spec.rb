# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Payment do
  let(:payment_id) { 'payment-O1' }

  it 'starts a payment' do
    with_reactor(Payment, payment_id:)
      .when(Payment::Start, payment_id:, order_id: 'O1', amount: 1000)
      .then(Payment::Started, payment_id:, order_id: 'O1', amount: 1000)
  end

  it 'is a no-op if the payment already started' do
    with_reactor(Payment, payment_id:)
      .given(Payment::Started, payment_id:, order_id: 'O1', amount: 1000)
      .when(Payment::Start, payment_id:, order_id: 'O1', amount: 1000)
      .then([])
  end

  it 'schedules a confirmation when the payment starts' do
    with_reactor(Payment, payment_id:)
      .when(Payment::Started, payment_id:, order_id: 'O1', amount: 1000)
      .then do |result|
        expect(result.messages.size).to eq(1)
        confirm = result.messages.first
        expect(confirm).to be_a(Payment::Confirm)
        expect(confirm.payload.payment_id).to eq(payment_id)
        expect(confirm.created_at).to be > Time.now + (Payment::PROVIDER_DELAY - 1)
      end
  end

  it 'confirms a started payment' do
    with_reactor(Payment, payment_id:)
      .given(Payment::Started, payment_id:, order_id: 'O1', amount: 1000)
      .when(Payment::Confirm, payment_id:)
      .then(Payment::Confirmed, payment_id:, order_id: 'O1')
  end

  it 'does not confirm a payment that has not started' do
    with_reactor(Payment, payment_id:)
      .when(Payment::Confirm, payment_id:)
      .then([])
  end

  it 'reports the confirmation back to the order' do
    with_reactor(Payment, payment_id:)
      .given(Payment::Started, payment_id:, order_id: 'O1', amount: 1000)
      .when(Payment::Confirmed, payment_id:, order_id: 'O1')
      .then(Order::ConfirmPayment, order_id: 'O1', payment_id:)
  end
end
