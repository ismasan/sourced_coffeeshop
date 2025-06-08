module Components
  class OrderItemModal < BaseComponent
    def initialize(order:, item_id:)
      @order = order
      @item = order.items.fetch(item_id)
    end

    def view_template
      Components::Modal(title: 'Order item') do |c|
        c.content do
          div class: 'item-details' do
            div(class: 'item-header') do
              div(class: 'item-names') do
                strong { @item.product_name }
                span(class: 'item-variant') { @item.variant_name }
              end
              span(class: 'item-quantity') do
                span(class: 'quantity') { @item.quantity.to_s }
                plain 'x'
                span(class: 'price') { @item.price.format }
                span(class: 'item-total') { @item.total.format }
              end
            end

            div class: 'item-quantity' do
              form_id = ['qty', @item.id].join('-')

              Sourced::UI::Components::Command(
                Order::UpdateItemQuantity, 
                stream_id: @order.id, 
                on: ['submit', 'change'],
                id: form_id,
                class: 'nice-form') do |form|
                  form.payload_fields(item_id: @item.id)
                  form.label do
                    span { 'Quantity' }
                    form.number_field(
                      :quantity, 
                      value: @item.quantity, 
                      name: 'quantity', 
                      class: 'nice-input', 
                      min: 1, 
                      required: true, 
                      step: 1
                    )
                  end
              end
            end

            div class: 'item-remove' do
              Sourced::UI::Components::Command(Order::RemoveItem, stream_id: @order.id, class: 'nice-form') do |form|
                form.payload_fields(item_id: @item.id)
                form.button(class: 'btn danger', type: 'submit') { 'x Remove' }
              end
            end
          end
        end
      end
    end
  end
end
