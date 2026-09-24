# frozen_string_literal: true

module Components
  # Messages sharing a correlation id, as a causation tree: which message
  # caused which. Rendered in a modal from the history sidebar.
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
                input(type: 'checkbox', data: { bind: '_showPayloads' })
                span { 'show payloads' }
              end
            end
          end
          c.content @component
        end
      end
    end

    def initialize(messages: [], highlighted: nil)
      @nodes = Sourced::UI::Dashboard.build_causation_tree(messages)
      @highlighted = highlighted
    end

    def view_template
      div(id: 'events-tree', class: 'events-timeline') do
        ul(class: 'tree tree-view') do
          @nodes.each do |node|
            render_node(node)
          end
        end
      end
    end

    private

    def render_node(node)
      li do
        message = node.message
        MessageRow(message, highlighted: @highlighted == message.id)

        if node.children.any?
          ul do
            node.children.each do |child|
              render_node(child)
            end
          end
        end
      end
    end
  end
end
