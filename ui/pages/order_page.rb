module Pages
  class OrderPage < Pages::Page

    def initialize(order:, layout: false)
      super(layout:)
      @order = order
    end

    def page_id = @order.id

    private

    def title = "#{@order.status} #{@order.id} - Sourced Coffee"

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'full') do |c|
            c.header do
              Components::StatusBadge(@order.status)
              h3 { @order.id }
            end
            c.content do
              order_items

              order_actions

              order_summary
            end
          end
        end
      end
    end

    def order_items
      div class: 'order-items' do
        @order.items.values.each do |item|
          data = _d.on.click.get(url("/orders/#{@order.id}/items/#{item.id}")).to_h

          div class: 'order-item', id: item.id, data: do
            h4 do
              strong { item.product_name }
              span(class: 'item-variant') { item.variant_name }
              span(class: 'item-quantity') do
                span(class: 'quantity') { item.quantity.to_s }
                plain 'x'
                span(class: 'price') { item.price.format }
              end
              span(class: 'item-total') { item.total.format }
            end
          end
        end
      end
    end

    def order_summary
      ul(class: 'order-summary') do
        li(class: 'order-summary--subtotal') do
          strong { 'Sub total: ' }
          span { @order.subtotal.format }
        end
        li(class: 'order-summary--tax') do
          strong { 'VAT: ' }
          span { @order.tax.format }
        end
        li(class: 'order-summary--total') do
          strong { 'Total: ' }
          span { @order.total.format }
        end
      end
    end

    def order_actions
      div class: 'order-actions' do
        if @order.open?
          a(class: 'btn primary', data: _d.on.click.get(url("/orders/#{@order.id}/catalog")).to_h) { '+ products'}
        end
      end
    end

  end
end
