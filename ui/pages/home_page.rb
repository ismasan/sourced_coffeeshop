# frozen_string_literal: true

module Pages
  class HomePage < Page
    path '/'

    # Re-render whenever either read model commits a batch.
    on OrderListings::Projected, PaymentListings::Projected do |_evt|
      browser.patch_elements load(params)
    end

    def self.load(_params, _ctx)
      new(orders: OrderListings.all, payments: PaymentListings.all)
    end

    def initialize(orders: [], payments: [])
      @orders = orders
      @payments = payments
    end

    private

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'half') do |c|
            c.header 'Recent orders'
            c.content do
              Components::OrdersTable(orders: @orders)
            end
          end

          Components::Card(size: 'half') do |c|
            c.header 'Payments'
            c.content do
              Components::PaymentsTable(payments: @payments)
            end
          end
        end
      end
    end
  end
end
