module Components
  class FulfillmentTable < BaseComponent
    def initialize(orders:)
      @orders = orders
    end

    def view_template
      table(id: 'orders-table', class: 'orders-table') do 
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
              td { a(href: url("/orders/#{order.id}/fulfillment")) { order.id } }
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
        order.items.values.each do |item|
          span(class: item.fetch(:status, 'pending')) { '' }
        end
      end
    end
  end
end
