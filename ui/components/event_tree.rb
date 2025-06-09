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
                input(type: 'checkbox', id: 'show-payloads', data: _d.on.change.run('$_showPayloads = !$_showPayloads').to_h)
                span { 'show payloads' }
              end
            end
          end
          c.content @component
        end
      end
    end

    Node = Struct.new(:parent, :children)

    def initialize(events: [], highlighted: nil, href_prefix: 'orders')
      @events = build_tree(events)
      @highlighted = highlighted
      @href_prefix = href_prefix
    end

    private def build_tree(events)
      # Create a lookup hash for quick access to events by ID
      node_map = events.each_with_object({}) { |event, map| map[event.id] = Node.new(event, []) }

      # Track root events (those without parents)
      root_nodes = []

      # Build parent-child relationships
      node_map.values.each do |node|
        if node.parent.causation_id == node.parent.id
          # This is a root event
          root_nodes << node
        else
          # Find parent and add this event as its child
          parent = node_map[node.parent.causation_id]
          parent.children << node if parent
        end
      end

      root_nodes
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
        event = node.parent
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
