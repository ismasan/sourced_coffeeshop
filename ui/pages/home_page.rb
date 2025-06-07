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
            c.header 'Workload'
            c.content do
              img src: '/images/simple_order_throughput_chart.svg', alt: 'Workload Chart', class: 'workload-chart'
            end
          end
        end
      end
    end
  end
end
