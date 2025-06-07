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

  get '/orders/:id/?' do |id|
    order = Order.load(id)
    phlex Pages::OrderPage.new(order: order.state, layout: true)
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
