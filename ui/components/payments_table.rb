# frozen_string_literal: true

module Components
  class PaymentsTable < BaseComponent
    # @param payments [Array<Hash>] rows from the payments table
    def initialize(payments:)
      @payments = payments
    end

    def view_template
      if @payments.empty?
        p { 'No payments yet' }
        return
      end

      table(id: 'payments-table', class: 'orders-table') do
        thead do
          th { 'status' }
          th(class: 'cell--order-id') { 'Order ID' }
          th(class: 'cell--datetime') { 'created at' }
          th { 'amount' }
        end
        tbody do
          @payments.each do |payment|
            tr do
              td do
                Components::StatusBadge(payment[:status])
              end
              td { a(href: "/orders/#{payment[:order_id]}") { payment[:order_id] } }
              td { format_time(Time.iso8601(payment[:created_at])) if payment[:created_at] }
              td(class: 'money') { Money.from_cents(payment[:amount]).format }
            end
          end
        end
      end
    end
  end
end
