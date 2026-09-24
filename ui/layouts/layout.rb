# frozen_string_literal: true

require 'digest/md5'

module Layouts
  # Page chrome: head, navigation bar, the page itself and the modal slot.
  # Sidereal::Components::Layout adds the Datastar script to <head>, and the
  # page signals + SSE subscription (`/updates/<channel>`) at the end of <body>.
  class Layout < Sidereal::Components::Layout
    HASHED_ASSETS = {}

    def view_template
      doctype

      html do
        head do
          meta(charset: 'utf-8')
          meta(name: 'viewport', content: 'width=device-width, initial-scale=1.0')
          title { page.page_title }
          link(rel: 'stylesheet', href: hashed_asset('/css/main.css'))
        end

        # `modal` drives the modal dialog slot below; the page's own signals
        # (page_key, params) are merged in by Sidereal's layout.
        body(data: { signals: { modal: false } }) do
          navigation if page.show_nav?

          render page

          div(id: 'modal', data: { show: '$modal' })
        end
      end
    end

    private

    def navigation
      div class: 'nav' do
        div class: 'link-group' do
          a(href: '/', class: ('current' if current_page?('/', exact: true))) { 'Home' }
          a(href: '/cashier', class: ('current' if current_page?('/cashier'))) { 'Cashier' }
          a(href: '/barista', class: ('current' if current_page?('/barista'))) { 'Barista' }
        end
        div class: 'link-group' do
          span(class: 'current-user desktop-only') { "logged in as #{context.session[:username]}" }
          a(class: 'logout', title: 'Logout', href: '/logout') { 'logout' }
          a(class: 'system desktop-only', title: 'Sourced dashboard', href: '/sourced') { '🛠' }
        end
      end
    end

    def current_page?(path, exact: false)
      current = context.request.path_info
      exact ? current == path : current.start_with?(path)
    end

    if ENV['RACK_ENV'] == 'production'
      def hashed_asset(path)
        HASHED_ASSETS[path] ||= "#{path}?#{Digest::MD5.file("public#{path}").hexdigest}"
      end
    else
      def hashed_asset(path)
        "#{path}?#{Time.now.to_i}"
      end
    end
  end
end
