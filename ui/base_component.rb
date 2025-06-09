# frozen_string_literal: true

class BaseComponent < Phlex::HTML
  include Sourced::UI::Components::DatastarHelpers

  private

  def dom_id(prefix)
    [prefix, SecureRandom.hex(4)].join('-')
  end
end
