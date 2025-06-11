module Pages
  class BaristaPage < Pages::Page

    def initialize(layout: false)
      super(layout:)
    end

    private

    def title = 'Barista - Sourced Coffee'

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'half') do |c|
            c.header 'Placed orders'
            c.content do
              Components::FulfillmentTable(orders: OrderListings.placed)
            end
          end

          Components::Card(size: 'half') do |c|
            c.header 'Ready to deliver'
            c.content do
              Components::DeliverablesTable(orders: Deliverables.all)
            end
          end
        end
      end
    end
  end
end
