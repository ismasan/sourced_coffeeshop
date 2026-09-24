# frozen_string_literal: true

module Pages
  # The barista's view of one placed order: start and finish each item.
  class FulfillmentPage < Page
    path '/orders/:id/fulfillment'

    on(*Order.handled_messages_for_evolve) do |_evt|
      browser.patch_elements load(params)
    end

    def self.load(params, _ctx)
      order, _messages = OrderPage.load_order(params[:id])
      new(order:)
    end

    def initialize(order:)
      @order = order
    end

    def page_title = "Fulfillment #{@order.id} - Sourced Coffee"
    def channel_name = "shop.orders.#{@order.id}"

    private

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'full') do |c|
            c.header do
              Components::StatusBadge(@order.status)
              h3 { @order.id }
            end

            c.content do
              div class: 'order-details' do
                if @order.created_at
                  small { "created at #{format_time(@order.created_at)} by #{@order.created_by}" }
                end

                a(href: "/orders/#{@order.id}") { 'order details' }
              end

              if @order.placed? || @order.fulfilled? || @order.delivered?
                order_items
              else
                p { "This order is #{@order.status}: nothing to fulfill yet." }
              end
            end
          end
        end
      end
    end

    def order_items
      div class: 'order-items' do
        @order.items.values.each do |item|
          div class: ['order-item', item.status], id: "item-#{item.id}" do
            h4 do
              strong { item.product_name }
              span(class: 'item-variant') { item.variant_name }
              span(class: 'item-quantity') { "x #{item.quantity}" }
            end
            div class: 'item-tools' do
              if item.pending? && @order.placed?
                command Order::StartItemFulfillment, key: item.id do |form|
                  form.payload_fields(order_id: @order.id, item_id: item.id)
                  form.button(class: 'btn pending', type: 'submit') { 'start' }
                end
              end

              if item.started?
                command Order::FulfillItem, key: item.id do |form|
                  form.payload_fields(order_id: @order.id, item_id: item.id)
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
