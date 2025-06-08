module Components
  class Modal < BaseComponent
    def initialize(title: 'Modal dialog', content: nil, buttons: true)
      @title = title
      @content = content
      @buttons = buttons
    end

    def view_template
      div(id: 'modal', data: { show: '$modal' }) do
        div(class: 'modal-underlay', data: { 'on-click' => '$modal = false' })
        div(class: 'modal-content') do
          div(class: 'modal-header') do
            h1 { @title }
            div(class: 'modal-buttons') do
              if @buttons
                button(class: 'btn danger', data: { 'on-click' => '$modal = false' }) do
                  'Close'
                end
              end
            end
          end

          if @content
            div(class: 'modal-body') do
              render @content
            end
          end
        end
      end
    end
  end
end
