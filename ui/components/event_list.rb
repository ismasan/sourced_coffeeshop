# frozen_string_literal: true

module Components
  # The order's history sidebar: every command and event in the order's
  # partition, newest first, numbered by step (position in the partition).
  # Each step links to a frozen snapshot of the order at that step.
  class EventList < BaseComponent
    def initialize(messages:, order_id:, step: nil)
      @messages = messages
      @order_id = order_id
      @last_step = messages.length
      @step = step || @last_step
    end

    def view_template
      # `_showPayloads` is page-local; __ifmissing keeps it across re-renders.
      div id: 'event-list', data: { 'signals__ifmissing' => { _showPayloads: false }.to_json } do
        div class: 'header' do
          div(class: 'history-tools') do
            h2 { 'History' }
            pagination if @messages.any?

            div(class: 'switches') do
              label(class: 'toggle-payloads') do
                input(type: 'checkbox', data: { bind: '_showPayloads' })
                span { 'show payloads' }
              end
            end
          end
        end
        div class: 'list' do
          @messages.each_with_index.to_a.reverse.each do |(message, index)|
            step = index + 1
            MessageRow(
              message,
              step:,
              highlighted: step == @step,
              href: step_href(step)
            )
          end
        end
      end
    end

    private

    def step_href(step)
      step == @last_step ? "/orders/#{@order_id}" : "/orders/#{@order_id}/#{step}"
    end

    def pagination
      span(class: 'pagination') do
        pager_link('←', @step - 1, enabled: @step > 1, title: 'Previous step')
        pager_link('→', @step + 1, enabled: @step < @last_step, title: 'Next step')
        span { "step: #{@step} of #{@last_step}" }
      end
    end

    def pager_link(label, step, enabled:, title:)
      if enabled
        a(class: 'pager-button', href: step_href(step), title:) { label }
      else
        button(disabled: true, title:) { label }
      end
    end
  end
end
