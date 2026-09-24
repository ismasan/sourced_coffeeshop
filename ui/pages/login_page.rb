# frozen_string_literal: true

module Pages
  class LoginPage < Page
    path '/login'

    def self.load(_params, _ctx) = new

    def initialize(username: nil, errors: {})
      @username = username
      @errors = errors
    end

    def page_title = 'Login - Sourced Coffee'
    def show_nav? = false
    # A plain form page: no SSE subscription.
    def channel_name = nil
    def page_signals = {}

    def view_template
      div(id: 'container', class: 'container login-container') do
        div(id: 'login-box', class: [('errors' if @errors.any?)]) do
          h1 { 'Login' }
          form(action: '/login', method: 'post', class: 'nice-form') do
            p { 'Please create a user name to begin' }
            if @errors.any?
              h4 { 'Errors' }
              ul class: 'error-list' do
                @errors.each do |field, message|
                  li { "#{field}: #{message}" }
                end
              end
            end
            div class: 'row' do
              input(
                type: 'text',
                name: 'username',
                value: @username,
                placeholder: 'Username',
                autocomplete: 'off',
                autofocus: true,
                class: ['nice-input', ('error' if @errors[:username])]
              )
              button(type: 'submit', class: 'nice-button') { 'Login' }
            end
          end
        end
      end
    end
  end
end
