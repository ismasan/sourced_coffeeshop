module Components
  class OrdersTable < BaseComponent
    def initialize(orders:)
      @orders = orders
    end

    def view_template

      table do 
        thead do
          th { 'Order ID' }
          th { 'status' }
          th { 'created at' }
          th { 'staff' }
          th { 'total' }
        end
        tbody do
          @orders.each do |order|
            tr do
              td { a(href: url("/orders/#{order.id}")) { order.id } }
              td do
                Components::StatusBadge(order.status)
              end
              td { order.created_at.strftime('%Y-%m-%d %H:%M') }
              td { order.members.join(', ') }
              td(class: 'money') { order.total }
            end
          end
        end
      end
    end
  end
end
