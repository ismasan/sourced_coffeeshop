# frozen_string_literal: true

module Components
  class OrdersTable < BaseComponent
    # @param orders [Array<OrderListings::Listing>]
    def initialize(orders:)
      @orders = orders
    end

    def view_template
      if @orders.empty?
        p { 'No orders yet' }
        return
      end

      table(id: 'orders-table', class: 'orders-table') do
        thead do
          th { 'status' }
          th(class: 'cell--order-id') { 'Order ID' }
          th(class: 'cell--datetime') { 'created at' }
          th { 'staff' }
          th { 'sub total' }
        end
        tbody do
          @orders.each do |order|
            tr do
              td do
                Components::StatusBadge(order.status)
              end
              td do
                a(href: "/orders/#{order.id}") { order.id }
                small { " (#{order.step})" }
              end
              td { order.created_at&.strftime('%Y-%m-%d %H:%M') }
              td { order.members.join(', ') }
              td(class: 'money') { order.total.format }
            end
          end
        end
      end
    end
  end
end
