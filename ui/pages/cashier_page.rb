module Pages
  class CashierPage < Pages::Page

    class CreateList < Phlex::HTML
      def view_template
        Sourced::UI::Components::Command(Todos::List::Create, class: 'nice-form') do |form|
          form.text_field('name', required: true, autocomplete: 'off', class: 'nice-input')
          button(class: 'nice-button', type: 'submit') { 'Create Todo List' }
        end
      end
    end

    def initialize(layout: false)
      super(layout:)
    end

    private

    def title = 'Cachier - Sourced Coffee'

    def container
      div id: 'main' do
        h1 { 'Gello' }
      end
    end
  end
end
