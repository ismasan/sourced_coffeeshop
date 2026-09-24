# frozen_string_literal: true

module Pages
  # One order: its items, totals, actions and, in the sidebar, its full
  # command/event history read straight from the Sourced log.
  #
  # With a +step+ (route +/orders/:id/:step+) it renders a frozen snapshot
  # instead: the order as of the Nth message of its history, with no SSE
  # subscription so live events can't overwrite it. The sidebar always lists
  # the whole history, so you can jump forward and back from any step.
  class OrderPage < Page
    path '/orders/:id'

    # Any order event re-renders the page from the log.
    on(*Order.handled_messages_for_evolve) do |_evt|
      browser.patch_elements load(params)
    end

    def self.load(params, _ctx, step: nil)
      order, messages = load_order(params[:id], upto: step)
      new(order:, messages:, step:)
    end

    # The order's partition, in log order, commands included: the sidebar
    # shows them all, and a step is a position in that list. The state is
    # rebuilt by replaying the first +upto+ messages through the Order
    # decider itself (commands have no evolve handler, so they're skipped).
    def self.load_order(order_id, upto: nil)
      messages = Sourced.store.read_partition({ order_id: }, handled_types: Order.display_types).messages
      evolved = upto ? messages.first(upto) : messages
      order = Order.new({ order_id: }).evolve(evolved)
      [order, messages]
    end

    def initialize(order:, messages: [], step: nil)
      @order = order
      @messages = messages
      @step = step
    end

    def page_title = "#{@order.status} #{@order.id} - Sourced Coffee"
    def historic? = !@step.nil?
    def valid_step? = !historic? || (@step >= 1 && @step <= @messages.length)

    # Live: this order's channel. Snapshot: no subscription at all.
    def channel_name = historic? ? nil : "shop.orders.#{@order.id}"
    def page_signals = historic? ? {} : super

    private

    def interactive? = !historic?

    def container
      div id: 'main', class: 'with-sidebar' do
        div class: 'cards-container' do
          Components::Card(size: 'full') do |c|
            c.header do
              Components::StatusBadge(@order.status)
              h3 { @order.id }
            end

            if historic?
              c.tools do
                span(class: 'audit-notice') do
                  span(class: 'audit-notice__label') { "step #{@step} of #{@messages.length}" }
                  a(href: "/orders/#{@order.id}", class: 'audit-notice__link') { 'back to live' }
                end
              end
            end

            c.content do
              order_details
              order_items
              order_actions
              order_summary
            end
          end

          order_next_steps
        end
      end

      div id: 'sidebar' do
        Components::EventList(messages: @messages, order_id: @order.id, step: @step)
      end
    end

    def order_details
      div class: 'order-details' do
        if @order.created_at
          small { "created at #{format_time(@order.created_at)} by #{@order.created_by}" }
        end

        if @order.placed?
          a(href: "/orders/#{@order.id}/fulfillment") { 'fulfillment' }
        end
      end
    end

    def order_items
      div class: 'order-items' do
        @order.items.values.each do |item|
          data = if interactive? && @order.open?
            _d.on.click.get("/orders/#{@order.id}/items/#{item.id}").to_h
          else
            {}
          end

          div class: ['order-item', item.status], id: "item-#{item.id}", data: do
            h4 do
              strong { item.product_name }
              span(class: 'item-variant') { item.variant_name }
            end

            div class: 'item-tools' do
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
      return unless interactive? && @order.open?

      div class: 'order-actions' do
        a(class: 'btn primary', data: _d.on.click.get("/orders/#{@order.id}/catalog").to_h) { '+ products' }
      end
    end

    def order_next_steps
      return unless interactive?

      if @order.open?
        Components::Card(size: 'full') do |c|
          c.content do
            div class: 'control-row' do
              command Order::Cancel, class: 'nice-form' do |f|
                f.payload_fields(order_id: @order.id)
                button(class: 'btn danger', type: 'submit') { 'Cancel order' }
              end

              command Order::Place, class: 'nice-form' do |f|
                f.payload_fields(order_id: @order.id)
                button(class: 'btn primary', type: 'submit', disabled: @order.items.empty?) { 'Place order' }
              end
            end
          end
        end
      end

      if @order.placed? || @order.fulfilled? || @order.delivered?
        Components::Card(size: 'full') do |c|
          c.header do
            Components::StatusBadge(@order.payment.status)
            h3 { 'Payment' }
          end

          c.content do
            if @order.payment.pending?
              command Order::StartPayment, class: 'nice-form' do |f|
                f.payload_fields(order_id: @order.id)
                button(type: 'submit', class: 'contactless', title: 'Tap to pay') do
                  img src: '/images/contactless-icon.svg', alt: 'Tap to pay', class: 'payment-started'
                end
              end
            elsif @order.payment.started?
              p { 'Waiting for the payment provider…' }
            else
              p { "Paid #{@order.total.format}" }
            end
          end
        end

        customer_name_card
      end
    end

    def customer_name_card
      Components::Card(size: 'full') do |c|
        c.header do
          h3 { 'Customer name' }
        end

        c.tools do
          # `_cnamedit` is a page-local signal; __ifmissing keeps its value
          # across SSE re-renders of the page.
          span(data: { 'signals__ifmissing' => { _cnamedit: false }.to_json })
          toggle = _d.on.click.run('$_cnamedit = !$_cnamedit').to_h.merge('text' => '$_cnamedit ? "cancel" : "edit"')
          a(class: 'btn primary', data: toggle) { 'edit' }
        end

        c.content do
          command Order::SetCustomerName, class: 'nice-form' do |f|
            f.payload_fields(order_id: @order.id)
            div class: 'input-row', data: { show: '$_cnamedit' } do
              f.text_field(:customer_name, value: @order.customer_name, placeholder: 'Customer name', class: 'nice-input')
              # Leave edit mode once submitted; the page re-renders with the new name.
              button(class: 'btn primary', type: 'submit', data: _d.on.click.run('$_cnamedit = false').to_h) { 'Update' }
            end
          end

          strong class: 'order-customer-name--edit', data: { show: '!$_cnamedit' } do
            @order.customer_name || '--'
          end
        end
      end
    end
  end
end
