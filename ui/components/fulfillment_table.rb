# frozen_string_literal: true

module Components
  class FulfillmentTable < BaseComponent
    # @param orders [Array<OrderListings::Listing>] placed orders
    def initialize(orders:)
      @orders = orders
    end

    def view_template
      if @orders.empty?
        p { 'No orders to prepare' }
        return
      end

      table(id: 'fulfillment-table', class: 'orders-table') do
        thead do
          th { 'status' }
          th(class: 'cell--order-id') { 'Order ID' }
          th(class: 'cell--progress') { 'Fulfilment' }
          th(class: 'cell--payment') { 'Payment' }
        end
        tbody do
          @orders.each do |order|
            tr do
              td do
                Components::StatusBadge(order.status)
              end
              td { a(href: "/orders/#{order.id}/fulfillment") { order.id } }
              td { progress(order) }
              td(class: "payment-#{order.payment_status}") { order.payment_status }
            end
          end
        end
      end
    end

    private

    def progress(order)
      div(class: 'fulfillment-progress') do
        order.items.each_value do |item|
          span(class: item.fetch(:status, 'pending'), title: item[:name]) { '' }
        end
      end
    end
  end
end
