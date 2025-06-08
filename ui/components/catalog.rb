module Components
  class Catalog < BaseComponent
    def initialize(products: [])
      @products = products
    end

    def view_template
      div class: 'products-grid' do
        @products.each do |product|
          div class: 'product-card' do
            h3(class: 'product-name') { product.name }
            div class: 'product-variants' do
              product.variants.each do |variant_id, variant|
                button(type: 'button', class: 'variant-button') do
                  span(class: 'variant-name') { variant.name }
                  span(class: 'variant-price') { "£#{(variant.price / 100.0).round(2)}" }
                end
              end
            end
          end
        end
      end
    end
  end
end
