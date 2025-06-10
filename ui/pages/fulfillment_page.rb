module Pages
  class FulfillmentPage < Pages::Page

    def initialize(order:, events: [], seq: nil, layout: false)
      super(layout:)
      @order = order
      @events = events
      @seq = seq || events.last&.seq || 0
      @interactive = events.last&.seq == @seq
    end

    def page_id = @order.id

    private

    def title = "#Fulfillment #{@order.id} - Sourced Coffee"

    def container
      div id: 'main', class: 'with-sidebar' do
        div class: 'cards-container' do
          Components::Card(size: 'full') do |c|
            c.header do
              Components::StatusBadge(@order.status)
              h3 { @order.id }
            end

            c.content do
              div class: 'order-details' do
                if @order.created_at
                  small do
                    "created at #{@order.created_at.strftime('%Y-%m-%d %H:%M:%S')} by #{@order.created_by}"
                  end
                end

                a(href: url("/orders/#{@order.id}")) { 'order details' }
              end

              order_items
            end
          end
        end
      end
    end

    def order_items
      div class: 'order-items' do
        @order.items.values.each do |item|
          div class: ['order-item', item.status], id: item.id, data: do
            h4 do
              strong { item.product_name }
              span(class: 'item-variant') { item.variant_name }
              span(class: 'item-quantity') { "x #{item.quantity}" }
            end
            div class: 'item-tools' do
              if item.pending?
                Sourced::UI::Components::Command(Order::StartItemFulfillment, stream_id: @order.id) do |form|
                  form.payload_fields(item_id: item.id)
                  form.button(class: 'btn pending', type: 'submit') { 'start' }
                end
              end

              if item.started?
                Sourced::UI::Components::Command(Order::FulfillItem, stream_id: @order.id, item_id: item.id) do |form|
                  form.payload_fields(item_id: item.id)
                  form.button(class: 'btn primary', type: 'submit') { 'finish' }
                end
              end

              if item.fulfilled?
                span(class: 'icon icon-tick') { '✔' }
              end
            end
          end
        end
      end
    end
  end
end
