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

  def self.load
    data = YAML.load_file(File.join(__dir__, '..', 'config', 'catalog.yml'))
    products = Products.parse(data)
    new(products)
  end

  def self.instance
    @instance ||= load
  end

  %i[find all by_category categories].each do |method|
    define_singleton_method method do |*args|
      instance.send(method, *args)
    end
  end

  attr_reader :products

  def initialize(products)
    @products = products
    @category_index = build_category_index
  end

  def find(id)
    products[id]
  end

  def all
    @products.values
  end

  def by_category(category)
    @category_index[category] || []
  end

  def categories = @category_index.keys.sort

  private def build_category_index
    @products.values.each.with_object({}) do |product, memo|
      product.categories.each do |category|
        (memo[category] ||= []) << product
      end
    end
  end
end
