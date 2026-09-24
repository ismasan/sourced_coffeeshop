# frozen_string_literal: true

module Components
  # The product catalog, in a modal. Each variant is an AddItem form.
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

    private

    def product_categories
      div class: 'products-categories' do
        # Changing the category re-fetches this modal with ?cat=...
        form(data: _d.on.change.get("/orders/#{@order_id}/catalog", content_type: 'form').to_h) do
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
            command Order::AddItem, key: "#{product.id}-#{variant.id}", class: 'nice-form' do |form|
              form.payload_fields(
                order_id: @order_id,
                product_id: product.id,
                variant_id: variant.id,
                product_name: product.name,
                variant_name: variant.name,
                price: variant.price.cents
              )
              button(type: 'submit', class: 'variant-button', data: _d.on.click.run('$modal = false').to_h) do
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
