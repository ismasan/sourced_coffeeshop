# frozen_string_literal: true

module Pages
  # Base for all pages. A page renders a `#container` root (the element
  # Datastar morphs when the page is re-rendered over SSE) and, by default,
  # subscribes to every channel under `shop.` so list pages see all orders
  # and payments. Pages scoped to one order narrow this down.
  class Page < Sidereal::Page
    include ViewHelpers

    def page_title = 'Sourced Coffee'
    def show_nav? = true
    def channel_name = 'shop.>'

    def view_template
      div(id: 'container', class: 'container') do
        container
      end
    end

    private

    def container
      h1 { page_title }
    end
  end
end
