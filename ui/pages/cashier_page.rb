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
          Components::Card(title: 'Actions', size: 'half') do
            Components::StartOrderCommand()
          end
          Components::Card(title: 'Recent orders', size: 'half') do
            Components::OrdersTable(orders: OrderListings.all)
          end
        end
      end
    end
  end
end
