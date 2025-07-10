module Components
  class OrdersTable < BaseComponent
    def initialize(orders:)
      @orders = orders
    end

    def view_template

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
                a(href: url("/orders/#{order.id}")) { order.id }
                small { " (#{order.seq})" }
              end
              td { order.created_at.strftime('%Y-%m-%d %H:%M') }
              td { order.members.join(', ') }
              td(class: 'money') { order.total.format }
            end
          end
        end
      end
    end
  end
end
