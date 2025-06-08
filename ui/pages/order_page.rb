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
          Components::Card(size: 'full') do |c|
            c.header do
              Components::StatusBadge(@order.status)
              h3 { @order.id }
            end
            c.content do
              ul do
                li do
                  strong { 'Total: ' }
                  plain @order.total.to_s
                end
              end
              if @order.open?
                a(class: 'nice-button', data: _d.on.click.get(url("/orders/#{@order.id}/catalog")).to_h) { 'Add products'}
              end
            end
          end
        end
      end
    end
  end
end
