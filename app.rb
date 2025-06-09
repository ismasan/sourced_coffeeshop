# frozen_string_literal: true

require 'sinatra/base'
require 'datastar'
require 'sourced/ui'

class App < Sinatra::Base
  helpers Phlex::Sinatra

  enable :sessions
  enable :method_override
  set :session_secret, ENV.fetch('SESSION_SECRET')

  User = Data.define(:username)

  helpers do
    def logged_in?
      !!session[:username]
    end

    def current_user
      @current_user ||= User.new(username: session[:username])
    end

    def order_id
      "O#{Time.now.strftime('%Y%m%H')}-#{SecureRandom.hex(4).upcase}"
    end

    def command_context
      @command_context ||= Sourced::CommandContext.new(
        stream_id: order_id,
        metadata: { 
          producer: 'UI',
          username: current_user&.username
        }
      )
    end

    def datastar
      @datastar ||= Datastar
        .new(request:, response:, view_context: self, heartbeat: 0.4)
                    .on_error do |err|
        puts "Datastar error: #{err}"
        puts err.backtrace.join("\n")
      end
    end

    def open_modal(component)
      datastar.send(:stream_no_heartbeat) do |sse|
        sse.merge_fragments component
        sse.merge_signals modal: true
      end
    end
  end

  get '/updates/?' do
    # TODO: here we're listening on a channel
    # shared by all clients
    # In reality we should scope by the current session, or tenant, or user, or todo-list
    # TODO: PG LISTEN allows subsribing to multiple channels
    # ie pubsub.subscribe(['system'], ['tenant-1'])
    # This could be beneficial
    # TODO: the browswer can disconnect (by default Datastar disconnects when the browser tab is not active)
    # Here we should re-render on reconnect, but NOT on page load.
    channel = Sourced.config.backend.pubsub.subscribe('system')

    datastar.on_connect do |*args|
      # Here we should keep track of whether 
      # this is an initial page load, or a reconnect.
      # and re-render if the latter.
      puts 'client connect'
    end
    datastar.on_client_disconnect do |*args|
      puts 'client disconnect'
      channel.stop
    end
    datastar.on_server_disconnect do |*args|
      puts 'server disconnect'
      channel.stop
    end
    datastar.on_error do |ex|
      puts "ERROR #{ex}"
      channel.stop
    end

    datastar.stream do |sse|
      channel.start do |evt, channel|
        case evt
        when Order::System::Updated
          if sse.signals['page_key'] == 'Pages::OrderPage' && sse.signals['page_id'] == evt.stream_id
            order = Order.load(evt.stream_id)
            sse.merge_fragments Pages::OrderPage.new(
              order: order.state,
              events: order.history
            )
          end
        when OrderListings::System::Updated
          if %w[Pages::HomePage Pages::CashierPage].include?(sse.signals['page_key'])
            # TODO: Writing listings and emitting event in same TX
            # seems to be breaking OrderListings.all
            # It load the new file but omits the "created_at" field for some reason
            # This sleep fixes it (??)
            sleep 0.1
            sse.merge_fragments Components::OrdersTable.new(orders: OrderListings.all)
          end
        else
          puts "Unknown event: #{evt}"
        end
      end
    end
  end

  get '/?' do
    if logged_in?
      phlex Pages::HomePage.new(layout: true)
    else
      phlex Pages::LoginPage.new
    end
  end

  post '/login/?' do
    form = Types::LoginForm.resolve(params)
    if form.valid?
      session[:username] = form.value[:username]
      redirect '/'
    else
      phlex Pages::LoginPage.new(
        params: form.value,
        errors: form.errors
      )
    end
  end

  get '/logout/?' do
    session.delete :username
    redirect '/'
  end

  get '/cashier' do
    phlex Pages::CashierPage.new(layout: true)
  end

  get '/barista' do
    phlex Pages::BaristaPage.new(layout: true)
  end

  get '/orders/:id/?' do |id|
    order = Order.load(id)
    phlex Pages::OrderPage.new(
      order: order.state, 
      events: order.history,
      layout: true
    )
  end

  get '/orders/:id/catalog/?' do |id|
    open_modal Components::Catalog.new(
      order_id: id, 
      category: params[:cat]
    )
  end

  get '/orders/:id/items/:item_id/?' do |order_id, item_id|
    order = Order.load(order_id)
    open_modal Components::OrderItemModal.new(
      order: order.state,
      item_id:
    )
  end

  # Load a todo list up to a given sequence number
  # Ex. /todo-lists/important-things/34
  get '/orders/:id/:upto?' do |id, upto|
    upto = Types::Lax::Integer.parse(upto)
    order = Order.load(id, upto:)
    # If this is an SSE request, stream the view back to to the browser
    # If a normal page load, render normally with layout
    if datastar.sse?
      datastar.stream do |sse|
        sse.execute_script <<-JS
          history.replaceState({}, '', '/orders/#{order.id}/#{upto}')
        JS
        sse.merge_fragments Pages::OrderPage.new(
          order: order.state,
          events: order.history,
          seq: upto,
        )
      end
    else
      phlex Pages::OrderPage.new(
        order: order.state, 
        events: order.history,
        seq: upto,
        layout: true
      )
    end
  end

  get '/events/:id/correlation/?' do |id|
    events = Sourced.config.backend.read_correlation_batch(id)
    open_modal Components::EventTree::Modal.new(
      events:,
      highlighted: id
    )
  end

  post '/commands/start-order' do
    cmd = command_context.build(params[:command].to_h)
    raise "Invalid command #{cmd.inspect}" if !cmd.valid?
    raise "Not an Order::Start command #{cmd.inspect}" if !cmd.is_a?(Order::Start)

    order, _ = Sourced.handle_command(cmd)
    redirect "/orders/#{order.id}"
  end

  post '/commands/?' do
    # TODO: eventually we want to check
    # that a given user is allowed to run a command
    cmd = command_context.build(params[:command].to_h)

    Sourced::UI.streaming_command_errors(cmd, datastar) do |cmd|
      Sourced.schedule_commands([cmd])
      halt 204
    end
  end
end


trap('INT') do
  puts('Closing!')
  sleep 1
  puts('Byebye!')
  exit
end
