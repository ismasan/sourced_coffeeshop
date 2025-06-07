module Components
  class StartOrderCommand < BaseComponent
    def view_template
      Sourced::UI::Components::Command(Order::Start, class: 'nice-form', ajax: false, href: url('/commands/start-order')) do |form|
        button(class: 'nice-button', type: 'submit') { 'Start order' }
      end
    end
  end
end
