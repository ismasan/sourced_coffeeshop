module Components
  class OrderItemModal < BaseComponent
    def initialize(order:, item_id:)
      @order = order
      @item = order.items.fetch(item_id)
    end

    def view_template
      Components::Modal(title: 'Order item') do |c|
        c.content do
          h4 do
            span { @item.product_name }
            span(class: 'item-variant') { @item.variant_name }
          end

          div class: 'item-quantity' do
            form do
              label do
                span { 'Quantity' }
                input(type: 'number', value: @item.quantity, name: 'quantity', class: 'nice-input', min: 1, required: true, step: 1)
              end
            end
          end

          div class: 'item-remove' do
            Sourced::UI::Components::Command(Order::RemoveItem, stream_id: @order.id, class: 'nice-form') do |form|
              form.payload_fields(item_id: @item.id)
              form.button(class: 'btn danger', type: 'submit') { 'Remove' }
            end
          end
        end
      end
    end
  end
end
