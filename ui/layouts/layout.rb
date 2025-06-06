module Layouts
  class Layout < Layouts::Base
    def initialize(title:, sse: '/updates')
      super(title: title)
      @sse = sse
    end

    private def current_page?(path)
      helpers.request.path.start_with?(path)
    end

    def view_template
      doctype

      html do
        head do
          meta(name: 'viewport', content: 'width=device-width, initial-scale=1.0')
          title { @title }
          link(rel: 'stylesheet', href: hashed_asset('/css/main.css'))
          script(type: 'module', src: 'https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.0-beta.11/bundles/datastar.js')
        end

        body(data: _d.signals(fetching: false, modal: false).to_h) do
          div class: 'nav' do
            div class: 'link-group' do
              a(href: '/cashier', class: ('current' if current_page?('/cashier') )) { 'Cashier' }
              a(href: '/barista', class: ('current' if current_page?('/barista'))) { 'Barista' }
            end
            div class: 'link-group' do
              span { "logged in as #{helpers.current_user.username}" }
              a(class: 'logout', href: '/logout') { 'Logout' }
              a(class: 'system', href: '/sourced') { '⚙' }
            end
          end

          yield
          div(id: 'modal', data: { show: '$modal' })
          onload = _d.on.load.get(url(@sse))
          # onload needs to be at the end
          # to make sure to collect all signals on the page
          div(data: onload.to_h)
        end
      end
    end
  end
end
