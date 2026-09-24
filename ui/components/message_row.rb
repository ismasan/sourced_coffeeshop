# frozen_string_literal: true

module Components
  # One command or event from the Sourced log.
  class MessageRow < BaseComponent
    def initialize(message, step: nil, href: nil, highlighted: false)
      @message = message
      @step = step
      @href = href
      @is_command = message.is_a?(Sourced::Command)
      @highlighted = highlighted
      @classes = [
        'event-card',
        'fade-in',
        (@is_command ? 'command' : 'event'),
        ('highlighted' if @highlighted)
      ]
    end

    def view_template
      div(id: "msg-#{message.id}", class: @classes) do
        div(class: 'event-header') do
          if @step
            span(class: 'event-sequence') do
              a(href: @href, title: "View order at step #{@step}") { @step.to_s }
            end
          end
          producer
          span(class: 'event-type') do
            # Opens the correlation tree modal: everything caused by the same request.
            a(data: _d.on.click.get("/messages/#{message.id}/correlation").to_h) { message.type }
          end
          span(class: 'event-timestamp') { format_time(message.created_at) }
          span(class: 'event-author') { message.metadata[:username].to_s }
        end
        if message.payload
          div(class: 'event-payload', data: { show: '$_showPayloads' }) do
            JSON.pretty_generate(message.payload.to_h)
          end
        end
      end
    end

    private

    attr_reader :message

    def producer
      code(class: 'event-producer') { safe("#{message.metadata[:producer]} &rarr;") } if message.metadata[:producer]
    end
  end
end
