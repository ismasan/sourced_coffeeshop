module Pages
  class HomePage < Pages::Page
    def initialize(layout: false)
      super(layout:)
    end

    private

    def title = 'Sourced Coffee'

    def container
      div id: 'main' do
        h1 { 'Gello' }
      end
    end
  end
end
