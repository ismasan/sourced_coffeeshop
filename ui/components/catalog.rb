module Components
  class Catalog < BaseComponent
    def initialize(order_id:, category: nil, categories: ::Catalog.categories)
      @order_id = order_id
      @categories = categories
      @category = category
      @products = ::Catalog.search(category:)
    end

    def view_template
      Components::Modal(title: 'Catalog') do |c|
        c.tools do
          product_categories
        end
        c.content do
          products_grid
        end
      end
    end

    def product_categories
      div class: 'products-categories' do
        href = url("/orders/#{@order_id}/catalog")
        form(data: _d.on.change.get(href, content_type: 'form').to_h) do
          select(name: 'cat') do
            @categories.each do |category|
              option(value: category.value, selected: @category == category.value) do
                plain "#{category.name} (#{category.count})"
              end
            end
          end
        end
      end
    end

    def products_grid
      div class: 'products-grid' do
        @products.each do |product|
          product_card(product)
        end
      end
    end

    def product_card(product)
      div class: 'product-card' do
        h3(class: 'product-name') { product.name }
        div class: 'product-variants' do
          product.variants.values.each do |variant|
            Sourced::UI::Components::Command(Order::AddItem, stream_id: @order_id, class: 'nice-form') do |form|
              form.payload_fields(
                product_id: product.id, 
                variant_id: variant.id,
                product_name: product.name,
                variant_name: variant.name,
                price: variant.price.cents
              )
              form.button(type: 'submit', class: 'variant-button', data: _d.on.click.run('$modal = false').to_h) do
                span(class: 'variant-name') { variant.name }
                span(class: 'variant-price') { variant.price.format }
              end
            end
          end
        end
      end
    end
  end
end
