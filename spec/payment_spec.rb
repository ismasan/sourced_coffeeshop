# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../boot'

RSpec.describe Payment do
  subject(:payment) { Payment.new(id: 'payment-1') }

  it 'starts a payment' do
    with_reactor(payment)
      .when(Payment::Start, order_id: 'o1', amount: 1000)
      .then(Payment::Started.build(payment.id, order_id: 'o1', amount: 1000))
  end

  it 'is a no-op if payment already started' do
    with_reactor(payment)
      .given(Payment::Started, order_id: 'o1', amount: 1000)
      .when(Payment::Start, order_id: 'o1', amount: 1000)
      .then([])
  end

  it 'confirms a started payment' do
    with_reactor(payment)
      .given(Payment::Started, order_id: 'o1', amount: 1000)
      .when(Payment::Confirm)
      .then([Payment::Confirmed.build(payment.id)])
  end

  it 'does not confirm a payment that has not started' do
    with_reactor(payment)
      .when(Payment::Confirm)
      .then([])
  end
end
