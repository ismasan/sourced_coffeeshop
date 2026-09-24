# frozen_string_literal: true

# One row per payment in the +payments+ table, for the home page's payments
# table. Publishes an auto-generated +Projected+ signal (attribute:
# payment_id) after each committed batch.
class PaymentListings < Sourced::Projector::StateStored
  consumer_group 'payment_listings'
  partition_by :payment_id

  TABLE = :payments

  def self.dataset = Sourced.store.db[TABLE]

  def self.all(limit: 100)
    dataset.order(Sequel.desc(:created_at)).limit(limit).all
  end

  def self.on_reset
    dataset.delete
  end

  state do |values|
    self.class.dataset.where(payment_id: values[:payment_id]).first ||
      { payment_id: values[:payment_id], order_id: nil, status: 'pending', amount: 0, created_at: nil }
  end

  evolve Payment::Started do |state, event|
    state[:order_id] = event.payload.order_id
    state[:amount] = event.payload.amount
    state[:status] = 'started'
    state[:created_at] = event.created_at.iso8601
  end

  evolve Payment::Confirmed do |state, _event|
    state[:status] = 'confirmed'
  end

  sync do |state:, **|
    next unless state[:order_id]

    self.class.dataset.insert_conflict(:replace).insert(state)
  end
end
