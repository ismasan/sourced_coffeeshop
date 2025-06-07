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
          Components::Card(title: 'Recent orders', size: 'half') do
            Components::OrdersTable(orders: OrderListings.all)
          end
          Components::Card(title: 'Workload', size: 'half') do
            img src: '/images/simple_order_throughput_chart.svg', alt: 'Workload Chart', class: 'workload-chart'
          end
        end
      end
    end
  end
end
