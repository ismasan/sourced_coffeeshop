class Payment < Sourced::Actor
  State = Struct.new(:id, :order_id, :amount, :status, :created_at)

  state do |id|
    State.new(id, nil, 0, :pending, nil)
  end

  command :start, order_id: Types::String.present, amount: Types::Lax::Integer do |state, cmd|
    return unless state.status == :pending

    event :started, cmd.payload
  end

  event :started, order_id: String, amount: Integer do |state, event|
    state.created_at = event.created_at
    state.order_id = event.payload.order_id
    state.amount = event.payload.amount
    state.status = :started
  end

  reaction :started do |state, event|
    sleep 2
    stream_for(event).command :confirm
  end

  command :confirm do |state, cmd|
    event :confirmed if state.status == :started
  end

  event :confirmed do |state, event|
    state.status = :confirmed
  end

  reaction :confirmed do |state, event|
    stream_for(state.order_id)
      .command Order::ConfirmPayment, payment_id: state.id
  end
end
