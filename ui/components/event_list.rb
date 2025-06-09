module Components
  class EventList < BaseComponent
    def initialize(events:, seq: nil, href_prefix: 'orders', reverse: true)
      @events = events
      @first_seq = @events.first&.seq
      @last_seq = @events.last&.seq
      @events = @events.reverse if reverse
      @seq = seq || @last_seq
      @href_prefix = href_prefix
    end

    def view_template
      div id: 'event-list', data: _d.signals(_showPayloads: false).to_h do
        div class: 'header' do
          if @events.any?
            disabled_back = @first_seq == @seq
            disabled_forward = @last_seq == @seq

            div(class: 'history-tools') do
              h2 { 'History' }
              span(class: 'pagination') do
                button(disabled: disabled_back,
                  data: _d.on.click.get("/#{@href_prefix}/#{@events.first.stream_id}/#{@seq - 1}").to_h) do
                  safe('&larr;')
                end
                button(disabled: disabled_forward,
                  data: _d.on.click.get("/#{@href_prefix}/#{@events.first.stream_id}/#{@seq + 1}").to_h) do
                  safe('&rarr;')
                end
                span { "sequence: #{@seq} " }
              end

              div(class: 'switches') do
                label(class: 'toggle-payloads') do
                  input(type: 'checkbox', id: 'show-payloads', data: _d.on.change.run('$_showPayloads = !$_showPayloads').to_h)
                  span { 'show payloads' }
                end
              end
            end
          end
        end
        div class: 'list' do
          @events.each do |event|
            MessageRow(
              event,
              highlighted: (event.seq == @seq),
              href: url("/#{@href_prefix}/#{event.stream_id}/#{event.seq}")
            )
          end
        end
      end
    end
  end
end
