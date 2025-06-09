module Components
  class Card < BaseComponent
    FULL_WIDTH = 'full'
    HALF = 'half'
    QUARTER = 'quarter'

    def initialize(size: FULL_WIDTH)
      @size = size
      @header = nil
      @tools = nil
      @content = nil
    end

    def view_template(&block)
      yield self

      div(class: ['card', @size]) do
        if @header || @tools
          div(class: 'card-header') do
            div(class: 'card-header-title', &@header) if @header
            div(class: 'card-header-tools desktop-only', &@tools) if @tools
          end
        end
        div(class: 'card-content', &@content) if @content
      end
    end

    def header(title = nil, &block)
      @header = if title
        proc do
          h3 { title }
        end
      else
        block
      end

      self
    end

    def tools(comp = nil, &block)
      @tools = if comp
        proc do
          h3 { render comp }
        end
      else
        block
      end

      self
    end

    def content(comp = nil, &block)
      @content = if comp
         proc { render comp }
      else
        block
      end

      self
    end
  end
end
