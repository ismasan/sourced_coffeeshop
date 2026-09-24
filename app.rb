# frozen_string_literal: true

# The coffee shop web app.
#
# Pages render from the read models (and, for one order, straight from the
# Sourced log) and subscribe to pubsub channels over SSE. Forms post
# commands to POST /commands; the app validates them, stamps the session
# user onto them and appends them to the Sourced store, where the Order and
# Payment deciders and the projectors pick them up.
class App < Sidereal::App
  session secret: ENV.fetch('SESSION_SECRET'), key: 'coffeeshop.session'
  layout Layouts::Layout

  PUBLIC_PATHS = %w[/login /logout].freeze

  # Everything but the login form needs a username in the session.
  before do
    unless logged_in? || PUBLIC_PATHS.include?(request.path_info)
      redirect '/login', status: 302
    end
  end

  # Stamp who did it (and from where) onto every command arriving over HTTP.
  # Events inherit this metadata through correlation, so read models and the
  # history sidebar can show it.
  before_command do |cmd|
    cmd.with_metadata(producer: 'UI', username: session[:username])
  end

  # Channel routing: one channel per order, one per payment, for everything
  # that carries the respective id (domain events, projector signals and
  # system notifications alike). List pages subscribe to `shop.>`, an
  # order's pages to `shop.orders.<id>`.
  channel_name do |msg|
    payload = msg.payload
    if payload.respond_to?(:order_id) && payload.order_id
      "shop.orders.#{payload.order_id}"
    elsif payload.respond_to?(:payment_id) && payload.payment_id
      "shop.payments.#{payload.payment_id}"
    else
      'shop.system'
    end
  end

  # ---- Session ----

  post '/login' do
    username = request.params['username'].to_s.strip
    if username.empty?
      component Pages::LoginPage.new(username:, errors: { username: 'is required' }), status: 422
    else
      session[:username] = username
      redirect '/', status: 302
    end
  end

  get '/logout' do
    session.clear
    redirect '/login', status: 302
  end

  # ---- Order snapshots (time travel) ----

  # The order replayed up to the Nth message of its history. Static: no SSE.
  get '/orders/:id/:step' do |id:, step:|
    step_int = Integer(step, 10, exception: false)
    halt 404, 'Not found' unless step_int&.positive?

    page = Pages::OrderPage.load(params, self, step: step_int)
    halt 404, 'Not found' unless page.valid_step?

    component page
  end

  # ---- Modals (SSE responses that patch the #modal slot) ----

  get '/orders/:id/catalog' do |id:|
    open_modal Components::Catalog.new(order_id: id, category: params[:cat])
  end

  get '/orders/:id/items/:item_id' do |id:, item_id:|
    order, _messages = Pages::OrderPage.load_order(id)
    halt 404, 'Not found' unless order.items.key?(item_id)

    open_modal Components::OrderItemModal.new(order:, item_id:)
  end

  get '/messages/:id/correlation' do |id:|
    messages = Sourced.store.read_correlation_batch(id)
    open_modal Components::EventTree::Modal.new(messages:, highlighted: id)
  end

  # ---- Commands exposed to the browser ----

  # Starting an order navigates to it. The Order decider processes the
  # command asynchronously; the order page catches up over SSE.
  handle Order::Start do |cmd|
    dispatch cmd
    browser.redirect "/orders/#{cmd.payload.order_id}"
  end

  handle Order::AddItem,
         Order::RemoveItem,
         Order::UpdateItemQuantity,
         Order::Cancel,
         Order::Place,
         Order::SetCustomerName,
         Order::StartItemFulfillment,
         Order::FulfillItem,
         Order::StartPayment,
         Order::DeliverOrder

  # ---- Pages ----

  page Pages::LoginPage
  page Pages::HomePage
  page Pages::CashierPage
  page Pages::BaristaPage
  page Pages::OrderPage
  page Pages::FulfillmentPage

  private

  def logged_in? = !session[:username].to_s.empty?

  # Patch the component into the layout's #modal slot and show it.
  def open_modal(component)
    browser.stream(heartbeat: false) do |sse|
      sse.patch_elements component
      sse.patch_signals modal: true
    end
  end
end
