# frozen_string_literal: true

module Components
  class StartOrderCommand < BaseComponent
    def view_template
      # The app's handler for Order::Start dispatches the command and
      # redirects the browser to the new order's page.
      command Order::Start, class: 'nice-form' do |form|
        form.payload_fields(order_id: Order.new_id)
        button(class: 'nice-button', type: 'submit') { 'Start order' }
      end
    end
  end
end
