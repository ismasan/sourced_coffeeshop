module Components
  class DeliverablesTable < BaseComponent
    def initialize(orders:)
      @orders = orders
    end

    def view_template
      if @orders.any?
        orders_table
      else
        p { 'No orders to deliver' }
      end
    end

    private

    def orders_table
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
                Components::StatusBadge('ready', label: order[:id])
              end
              td { order[:customer_name] }
              td do
                a(href: url("/orders/#{order[:id]}")) do
                  'details'
                end
              end
              td do
                Sourced::UI::Components::Command(Order::DeliverOrder, stream_id: order[:id], class: 'nice-form') do |form|
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
