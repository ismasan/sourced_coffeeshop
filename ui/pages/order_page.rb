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

            c.tools do
              if !@interactive
                Components::StatusBadge('auditing')
              end
            end

            c.content do
              div class: 'order-details' do
                if @order.created_at
                  small do
                    "created at #{@order.created_at.strftime('%Y-%m-%d %H:%M:%S')} by #{@order.created_by}"
                  end
                end

                if @order.placed?
                  a(href: url("/orders/#{@order.id}/fulfillment")) { 'fulfillment' }
                end
              end

              order_items

              order_actions

              order_summary
            end
          end

          order_next_steps
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
          data = if @interactive && @order.open?
            _d.on.click.get(url("/orders/#{@order.id}/items/#{item.id}")).to_h
          else
            {}
          end

          div class: ['order-item', item.status], id: item.id, data: do
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
      return unless @interactive

      div class: 'order-actions' do
        if @order.open?
          a(class: 'btn primary', data: _d.on.click.get(url("/orders/#{@order.id}/catalog")).to_h) { '+ products'}
        end
      end
    end

    def order_next_steps
      return unless @interactive

      if @order.open?
        Components::Card(size: 'full') do |c|
          c.content do
            div class: 'control-row' do
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

      Components::Card(size: 'full') do |c|
        c.header do
          Components::StatusBadge(@order.payment.status)
          h3 { 'Payment' }
        end

        c.content do
          if !@order.open? && @order.payment.pending?
            Sourced::UI::Components::Command(Order::StartPayment, stream_id: @order.id, class: 'nice-form') do |form|
              form.button(class: 'btn primary btn-full', type: 'submit') { '£ start payment' }
            end
          end
          if @order.payment.started?
            Sourced::UI::Components::Command(Payment::Start, stream_id: @order.payment.id, class: 'nice-form') do |form|
              form.payload_fields(order_id: @order.id, amount: @order.total.cents)
              form.button(type: 'submit', class: 'contactless') do
                img src: '/images/contactless-icon.svg', alt: 'Payment started', class: 'payment-started'
              end
            end
          end
        end
      end

      if @order.placed?
        Components::Card(size: 'full') do |c|
          c.header do
            h3 { 'Customer name' }
          end

          c.tools do
            signals = _d.signals(_cnamedit: false).to_h
            data_change = _d.on.click.run('$_cnamedit = !$_cnamedit').to_h.merge('text' => '$_cnamedit ? "cancel" : "edit"')
            span(data: signals)
            if @interactive
              a(class: 'btn primary', data: data_change) { 'edit' }
            end
          end

          c.content do
            if @interactive
              Sourced::UI::Components::Command(Order::SetCustomerName, stream_id: @order.id, class: 'nice-form') do |form|
                div class: 'input-row', data: { show: '$_cnamedit' } do
                  form.text_field(:customer_name, value: @order.customer_name, placeholder: 'Customer name')
                  form.button(class: 'btn primary', type: 'submit') { 'Update' }
                end
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
end
