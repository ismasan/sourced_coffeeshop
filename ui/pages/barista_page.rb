# frozen_string_literal: true

module Pages
  class BaristaPage < Page
    path '/barista'

    on OrderListings::Projected, Deliverables::Projected do |_evt|
      browser.patch_elements load(params)
    end

    def self.load(_params, _ctx)
      new(orders: OrderListings.placed, deliverables: Deliverables.all)
    end

    def initialize(orders: [], deliverables: [])
      @orders = orders
      @deliverables = deliverables
    end

    def page_title = 'Barista - Sourced Coffee'

    private

    def container
      div id: 'main' do
        div class: 'cards-container' do
          Components::Card(size: 'half') do |c|
            c.header 'Placed orders'
            c.content do
              Components::FulfillmentTable(orders: @orders)
            end
          end

          Components::Card(size: 'half') do |c|
            c.header 'Ready to deliver'
            c.content do
              Components::DeliverablesTable(orders: @deliverables)
            end
          end
        end
      end
    end
  end
end
