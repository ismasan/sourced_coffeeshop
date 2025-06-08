# frozen_string_literal: true

require 'yaml'

class Catalog
  StringToSymbol = Types::String.transform(Symbol, &:to_sym)
  SymbolizedHash = Types::Hash[StringToSymbol, Types::Any]

  class Variant < Types::Data
    attribute :name, Types::String
    attribute :price, Types::Integer
  end

  class Product < Types::Data
    attribute :name, Types::String
    attribute :categories, [String]
    attribute :variants, Types::Hash[String, SymbolizedHash >> Variant]
  end

  ProductPipe = SymbolizedHash >> Product

  Products = Types::Hash[String, ProductPipe]

  Category = Struct.new(:name, :value, :count) do
    def <=> (other)
      name <=> other.name
    end

    def to_option
      [name, value]
    end
  end

  def self.load
    data = YAML.load_file(File.join(__dir__, '..', 'config', 'catalog.yml'))
    products = Products.parse(data)
    new(products)
  end

  def self.instance
    @instance ||= load
  end

  %i[search all categories].each do |method|
    define_singleton_method method do |**args|
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

  ByCategory = ->(category) do
    proc do |list|
      list.filter do |product|
        product.categories.include?(category)
      end
    end
  end

  def search(category: nil)
    query = ->(list) { list }
    query = query >> ByCategory.(category) unless category.nil? || category == ALL
    query.(all)
  end

  def all
    @products.values
  end

  def by_category(category)
    @category_index[category] || []
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
