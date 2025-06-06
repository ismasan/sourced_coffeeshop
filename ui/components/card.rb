module Components
  class Card < BaseComponent
    FULL_WIDTH = 'full'
    HALF = 'half'
    QUARTER = 'quarter'

    def initialize(title: nil, size: FULL_WIDTH)
      @title = title
      @size = size
    end

    def view_template(&)
      div(class: ['card', @size]) do
        if @title
          div(class: 'card-header') do
            h3 { @title }
          end
        end

        div(class: 'card-content', &) if block_given?
      end
    end
  end
end
