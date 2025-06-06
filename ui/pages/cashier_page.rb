module Pages
  class CashierPage < Pages::Page

    def initialize(layout: false)
      super(layout:)
    end

    private

    def title = 'Cachier - Sourced Coffee'

    def container
      div id: 'main' do
        div(class: 'actions') do
          Components::StartOrderCommand()
        end
      end
    end
  end
end
