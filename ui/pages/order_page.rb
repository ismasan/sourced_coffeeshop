module Pages
  class OrderPage < Pages::Page

    def initialize(order:, layout: false)
      super(layout:)
      @order = order
    end

    private

    def title = "Order #{@order.id} - Sourced Coffee"

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'two-thirds') do |c|
            c.header('Products')
            c.content do 
              p { 'gello'}
            end
          end
          Components::Card(size: 'one-third') do |c|
            c.header do
              Components::StatusBadge(@order.status)
              h3 { @order.id }
            end
            c.content { 'aaa' }
          end
        end
      end
    end
  end
end
