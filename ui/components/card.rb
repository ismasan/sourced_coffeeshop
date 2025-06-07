module Components
  class Card < BaseComponent
    FULL_WIDTH = 'full'
    HALF = 'half'
    QUARTER = 'quarter'

    def initialize(size: FULL_WIDTH)
      @size = size
    end

    def view_template(&block)
      div(class: ['card', @size]) do
        yield self
      end
    end

    def header(title = nil, &block)
      if title
        div(class: 'card-header') do
          h3 { title }
        end
      else
        div(class: 'card-header', &block)
      end
    end

    def content(&block)
      div(class: 'card-content', &block)
    end
  end
end
