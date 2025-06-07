module Pages
  class CashierPage < Pages::Page

    def initialize(layout: false)
      super(layout:)
    end

    private

    def title = 'Cashier - Sourced Coffee'

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'half') do |c|
            c.header 'Actions'
            c.content do
              Components::StartOrderCommand()
            end
          end

          Components::Card(size: 'half') do |c|
            c.header 'Recent orders'
            c.content do
              Components::OrdersTable(orders: OrderListings.all)
            end
          end
        end
      end
    end
  end
end
