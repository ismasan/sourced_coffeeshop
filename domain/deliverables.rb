# frozen_string_literal: true

# Orders ready to hand over: fulfilled AND paid, but not yet delivered.
#
# An event-sourced projector: its state is rebuilt from the order's full
# history on every batch, so it never has to persist anything but the rows
# it exposes. It is also an automation. Once an order becomes deliverable it
# schedules a DeliverOrder command a few seconds later (a grace period during
# which the barista can deliver by hand from the barista page).
class Deliverables < Sourced::Projector::EventSourced
  consumer_group 'deliverables'
  partition_by :order_id

  TABLE = :deliverables
  AUTO_DELIVER_AFTER = 5 # seconds

  def self.dataset = Sourced.store.db[TABLE]

  def self.all(limit: 100)
    dataset.order(Sequel.desc(:ready_at)).limit(limit).all
  end

  def self.on_reset
    dataset.delete
  end

  state do |values|
    {
      order_id: values[:order_id],
      customer_name: nil,
      fulfilled: false,
      paid: false,
      delivered: false,
      ready_at: nil,
      # id of the event that made the order deliverable, so only the
      # reaction to that one event schedules the delivery.
      ready_by: nil
    }
  end

  def self.ready?(state) = state[:fulfilled] && state[:paid] && !state[:delivered]

  def self.check_ready(state, event)
    return if state[:ready_by] || !ready?(state)

    state[:ready_at] = event.created_at.iso8601
    state[:ready_by] = event.id
  end

  evolve Order::CustomerNameSet do |state, event|
    state[:customer_name] = event.payload.customer_name
  end

  evolve Order::OrderFulfilled do |state, event|
    state[:fulfilled] = true
    self.class.check_ready(state, event)
  end

  evolve Order::PaymentConfirmed do |state, event|
    state[:paid] = true
    self.class.check_ready(state, event)
  end

  evolve Order::OrderDelivered do |state, _event|
    state[:delivered] = true
  end

  sync do |state:, **|
    if self.class.ready?(state)
      self.class.dataset.insert_conflict(:replace).insert(
        order_id: state[:order_id],
        customer_name: state[:customer_name],
        ready_at: state[:ready_at]
      )
    else
      self.class.dataset.where(order_id: state[:order_id]).delete
    end
  end

  # Automation: deliver automatically shortly after the order becomes ready.
  # DeliverOrder is a no-op on the Order if a human delivered it first.
  reaction Order::OrderFulfilled, Order::PaymentConfirmed do |state, event|
    next unless state[:ready_by] == event.id

    dispatch(Order::DeliverOrder, order_id: event.payload.order_id).at(Time.now + AUTO_DELIVER_AFTER)
  end
end
