module Components
  class Modal < BaseComponent
    def initialize(title: 'Modal dialog', buttons: true)
      @title = title
      @buttons = buttons
      @content = nil
      @tools = nil
    end

    def view_template(&)
      yield self

      div(id: 'modal', data: { show: '$modal' }) do
        div(class: 'modal-underlay', data: { 'on-click' => '$modal = false' })
        div(class: 'modal-content') do
          div(class: 'modal-header') do
            h1 { @title }
            if @tools
              div(class: 'modal-tools', &@tools)
            end
            div(class: 'modal-buttons') do
              if @buttons
                button(class: 'btn danger', data: { 'on-click' => '$modal = false' }) do
                  'Close'
                end
              end
            end
          end

          if @content
            div(class: 'modal-body', &@content)
          end
        end
      end
    end

    def content(&block)
      @content = block
      self
    end

    def tools(&block)
      @tools = block
      self
    end
  end
end
