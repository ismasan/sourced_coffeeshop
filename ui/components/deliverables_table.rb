# frozen_string_literal: true

module Components
  class DeliverablesTable < BaseComponent
    # @param orders [Array<Hash>] rows from the deliverables table
    def initialize(orders:)
      @orders = orders
    end

    def view_template
      if @orders.empty?
        p { 'No orders to deliver' }
        return
      end

      table(id: 'deliverables-table', class: 'orders-table') do
        thead do
          th(class: 'cell--order-id') { 'Order ID' }
          th { 'Customer' }
          th { '' }
          th { '' }
        end
        tbody do
          @orders.each do |order|
            tr do
              td do
                Components::StatusBadge('ready', label: order[:order_id])
              end
              td { order[:customer_name] || '--' }
              td do
                a(href: "/orders/#{order[:order_id]}") { 'details' }
              end
              td do
                command Order::DeliverOrder, key: order[:order_id], class: 'nice-form' do |form|
                  form.payload_fields(order_id: order[:order_id])
                  form.button(class: 'btn primary', type: 'submit') { 'Deliver' }
                end
              end
            end
          end
        end
      end
    end
  end
end
