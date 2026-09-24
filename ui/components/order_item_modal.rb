# frozen_string_literal: true

module Components
  # Edit one order item: change its quantity, or remove it.
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
              # Submits on change as well as on submit, so the stepper alone updates the quantity.
              command Order::UpdateItemQuantity, key: @item.id, on: %w[submit change], class: 'nice-form' do |form|
                form.payload_fields(order_id: @order.id, item_id: @item.id)
                label do
                  span { 'Quantity' }
                  form.number_field(:quantity, value: @item.quantity, class: 'nice-input', min: 1, required: true, step: 1)
                end
              end
            end

            div class: 'item-remove' do
              command Order::RemoveItem, key: @item.id, class: 'nice-form' do |form|
                form.payload_fields(order_id: @order.id, item_id: @item.id)
                button(class: 'btn danger', type: 'submit', data: _d.on.click.run('$modal = false').to_h) { 'x Remove' }
              end
            end
          end
        end
      end
    end
  end
end
