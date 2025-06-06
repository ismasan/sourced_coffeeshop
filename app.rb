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

    def command_context
      @command_context ||= Sourced::CommandContext.new(
        stream_id: SecureRandom.uuid,
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
      phlex Pages::HomePage.new(lists: Todos::Listings.all, layout: true)
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
end
