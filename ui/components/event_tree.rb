module Components
  class EventTree < BaseComponent
    class Modal < BaseComponent
      def initialize(**kargs)
        @component = Components::EventTree.new(**kargs)
      end

      def view_template
        Components::Modal(title: 'Event correlation') do |c|
          c.tools do
            div(class: 'switches') do
              label(class: 'toggle-payloads') do
                data = _d.on.change.run('$_showPayloads = !$_showPayloads').to_h.merge(
                  'attr-checked' => '$_showPayloads',
                )
                input(type: 'checkbox', id: dom_id('payload-toggle'), data:)
                span { 'show payloads' }
              end
            end
          end
          c.content @component
        end
      end
    end

    def initialize(events: [], highlighted: nil, href_prefix: 'orders')
      @events = Sourced::UI::Dashboard.build_causation_tree(events)
      @highlighted = highlighted
      @href_prefix = href_prefix
    end

    def view_template
      div(id: 'events-tree', class: 'events-timeline') do
        ul(class: 'tree tree-view') do
          @events.each do |node|
            render_node(node)
          end
        end
      end
    end

    def render_node(node)
      li do
        event = node.message
        MessageRow(
          event,
          href: nil,
          highlighted: @highlighted == event.id
        )

        if node.children.any?
          ul do
            node.children.each do |child|
              render_node(child)
            end
          end
        end
      end
    end

    def producer_for(event)
      code { "[#{event.metadata[:producer]}] " } if event.metadata[:producer]
    end

    private def is_command?(event)
      event.id == event.causation_id
    end
  end
end
