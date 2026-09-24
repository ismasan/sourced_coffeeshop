# frozen_string_literal: true

module Pages
  class CashierPage < Page
    path '/cashier'

    on OrderListings::Projected do |_evt|
      browser.patch_elements load(params)
    end

    def self.load(_params, _ctx)
      new(orders: OrderListings.all)
    end

    def initialize(orders: [])
      @orders = orders
    end

    def page_title = 'Cashier - Sourced Coffee'

    private

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'half') do |c|
            c.header 'Actions'
            c.content do
              Components::StartOrderCommand()
            end
          end

          Components::Card(size: 'half') do |c|
            c.header 'Recent orders'
            c.content do
              Components::OrdersTable(orders: @orders)
            end
          end
        end
      end
    end
  end
end
