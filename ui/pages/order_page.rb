module Pages
  class OrderPage < Pages::Page

    def initialize(order:, events: [], seq: nil, layout: false)
      super(layout:)
      @order = order
      @events = events
      @seq = seq || events.last&.seq || 0
      @interactive = events.last&.seq == @seq
    end

    def page_id = @order.id

    private

    def title = "#{@order.status} #{@order.id} - Sourced Coffee"

    def container
      div id: 'main', class: 'with-sidebar' do
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

              order_next_steps
            end
          end
        end
      end

      div id: 'sidebar' do
        Components::EventList(
          events: @events,
          seq: @seq,
        )
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
      return unless @interactive

      div class: 'order-actions' do
        if @order.open?
          a(class: 'btn primary', data: _d.on.click.get(url("/orders/#{@order.id}/catalog")).to_h) { '+ products'}
        end
      end
    end

    def order_next_steps
      return unless @interactive

      if @order.placed?
        div class: 'order-customer-name', data: _d.signals(_cnamedit: false).to_h do
          Sourced::UI::Components::Command(Order::SetCustomerName, stream_id: @order.id, class: 'nice-form') do |form|
            div class: 'input-row', data: { show: '$_cnamedit' } do
              form.text_field(:customer_name, value: @order.customer_name, placeholder: 'Customer name')
              form.button(class: 'btn primary', type: 'submit') { 'Update' }
            end
            p class: 'order-customer-name--edit', data: { show: '!$_cnamedit' } do
              span { 'customer: ' }
              strong { @order.customer_name || '--' }
              a(href: '#', data: _d.on.click.run('$_cnamedit = true').to_h) { 'edit' }
            end
          end
        end
      end

      div class: 'order-next-steps' do
        if @order.open?
          Sourced::UI::Components::Command(Order::Cancel, stream_id: @order.id, class: 'nice-form') do |form|
            form.button(class: 'btn danger', type: 'submit') { 'Cancel order' }
          end

          Sourced::UI::Components::Command(Order::Place, stream_id: @order.id, class: 'nice-form') do |form|
            form.button(class: 'btn primary', type: 'submit') { 'Place order' }
          end
        end
      end
    end
  end
end
