module Pages
  class HomePage < Pages::Page
    def initialize(layout: false)
      super(layout:)
    end

    private

    def title = 'Sourced Coffee'

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'half') do |c|
            c.header 'Recent orders'
            c.content do
              Components::OrdersTable(orders: OrderListings.all)
            end
          end

          Components::Card(size: 'half') do |c|
            c.header 'Payments'
            c.content do
              table(id: 'payments-table', class: 'orders-table') do 
                thead do
                  th { 'status' }
                  th(class: 'cell--order-id') { 'Order ID' }
                  th(class: 'cell--datetime') { 'created at' }
                  th { 'amount' }
                end

                PaymentListings.all.each do |payment|
                  tr do
                    td do
                      Components::StatusBadge(payment[:status])
                    end
                    td { a(href: url("/orders/#{payment[:order_id]}")) { payment[:order_id] } }
                    td { payment[:created_at] }
                    td(class: 'money') { Money.from_cents(payment[:amount]).format }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
