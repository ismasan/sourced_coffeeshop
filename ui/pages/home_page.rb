module Pages
  class HomePage < Pages::Page
    def initialize(layout: false)
      super(layout:)
    end

    private

    def title = 'Sourced Coffee'

    def container
      div id: 'main' do
        h1 { 'Gello' }

        div class: 'cards-container' do
          Components::Card() do
            p { 'full' }
          end
          Components::Card(title: 'Recent orders', size: 'half') do
            Components::OrdersTable(orders: OrderListings.all)
          end
          Components::Card(title: 'Workload', size: 'quarter') do
            p { 'quarter' }
          end
          Components::Card(size: 'quarter') do
            p { 'quarter' }
          end
        end
      end
    end
  end
end
