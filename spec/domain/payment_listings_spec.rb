# frozen_string_literal: true

require 'spec_helper'

# A StateStored projector evolves the claimed batch on top of the stored row.
# For a projector the `given` messages are the batch it consumes, and `then!`
# runs the sync block that writes the row.
RSpec.describe PaymentListings do
  let(:payment_id) { 'payment-O1' }

  it 'writes a row for a started payment, keyed by its id' do
    with_reactor(PaymentListings, payment_id:)
      .given(Payment::Started, payment_id:, order_id: 'O1', amount: 1000)
      .then!

    expect(PaymentListings.all).to contain_exactly(
      include(payment_id:, order_id: 'O1', amount: 1000, status: 'started')
    )
  end

  it 'confirms on top of the stored row' do
    with_reactor(PaymentListings, payment_id:)
      .given(Payment::Started, payment_id:, order_id: 'O1', amount: 1000)
      .then!

    with_reactor(PaymentListings, payment_id:)
      .given(Payment::Confirmed, payment_id:, order_id: 'O1')
      .then!

    expect(PaymentListings.all).to contain_exactly(
      include(payment_id:, order_id: 'O1', amount: 1000, status: 'confirmed')
    )
  end
end
