# frozen_string_literal: true

# A payment against an order, in its own partition (+payment_id+).
#
# Simulates a slow payment provider: a started payment is confirmed 5 seconds
# later via a scheduled Confirm command, and the confirmation is reported back
# to the order with Order::ConfirmPayment.
class Payment < Sourced::Decider
  consumer_group 'payments'
  partition_by :payment_id

  PROVIDER_DELAY = 5 # seconds

  # ---- Commands ----

  Start = Sourced::Command.define('payments.start') do
    attribute :payment_id, Types::String.present
    attribute :order_id, Types::String.present
    attribute :amount, Integer
  end

  Confirm = Sourced::Command.define('payments.confirm') do
    attribute :payment_id, Types::String.present
  end

  # ---- Events ----

  Started = Sourced::Event.define('payments.started') do
    attribute :payment_id, String
    attribute :order_id, String
    attribute :amount, Integer
  end

  Confirmed = Sourced::Event.define('payments.confirmed') do
    attribute :payment_id, String
    attribute :order_id, String
  end

  # ---- State ----

  State = Struct.new(:id, :order_id, :amount, :status, :created_at)

  state do |values|
    State.new(values[:payment_id], nil, 0, :pending, nil)
  end

  command Start do |state, cmd|
    return unless state.status == :pending

    event Started, cmd.payload.to_h
  end

  evolve Started do |state, event|
    state.created_at = event.created_at
    state.order_id = event.payload.order_id
    state.amount = event.payload.amount
    state.status = :started
  end

  # The "payment provider" confirms after a delay: a future-dated command is
  # deferred by the store and promoted into the log when due.
  reaction Started do |_state, event|
    dispatch(Confirm, payment_id: event.payload.payment_id).at(Time.now + PROVIDER_DELAY)
  end

  command Confirm do |state, cmd|
    return unless state.status == :started

    event Confirmed, payment_id: cmd.payload.payment_id, order_id: state.order_id
  end

  evolve Confirmed do |state, _event|
    state.status = :confirmed
  end

  reaction Confirmed do |state, event|
    dispatch Order::ConfirmPayment, order_id: state.order_id, payment_id: event.payload.payment_id
  end
end
