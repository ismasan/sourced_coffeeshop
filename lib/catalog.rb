# frozen_string_literal: true

require 'yaml'

# The product catalog, loaded once from config/catalog.yml.
class Catalog
  class Variant < Types::Data
    attribute :id, String
    attribute :name, String
    attribute :price, Types::Money
  end

  class Product < Types::Data
    attribute :id, String
    attribute :name, String
    attribute :categories, Types::Array[String]
    attribute :variants, Types::Hash[String, Variant]
  end

  Category = Struct.new(:name, :value, :count) do
    def <=>(other)
      name <=> other.name
    end

    def to_option
      [name, value]
    end
  end

  # The YAML keys are the product and variant ids.
  def self.load
    data = YAML.load_file(File.join(__dir__, '..', 'config', 'catalog.yml'))
    products = data.to_h do |id, attrs|
      variants = attrs.fetch('variants').to_h do |variant_id, vattrs|
        [variant_id, Variant.new(id: variant_id, name: vattrs.fetch('name'), price: vattrs.fetch('price'))]
      end
      [id, Product.new(id:, name: attrs.fetch('name'), categories: attrs.fetch('categories'), variants:)]
    end
    new(products)
  end

  def self.instance
    @instance ||= load
  end

  %i[search all categories].each do |method|
    define_singleton_method(method) do |**args|
      instance.send(method, **args)
    end
  end

  def self.[](id)
    instance[id]
  end

  attr_reader :products, :categories

  ALL = 'all'

  def initialize(products)
    @products = products
    @category_index = build_category_index
    all_cat = Category.new('All', ALL, @products.size)
    @categories = [all_cat, *@category_index.values.sort]
  end

  def [](id)
    products[id]
  end

  def search(category: nil)
    return all if category.nil? || category == ALL

    all.select { |product| product.categories.include?(category) }
  end

  def all
    @products.values
  end

  private def build_category_index
    @products.values.each.with_object({}) do |product, memo|
      product.categories.each do |category|
        memo[category] ||= Category.new(category, category, 0)
        memo[category].count += 1
      end
    end
  end
end
