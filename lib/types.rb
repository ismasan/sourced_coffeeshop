# frozen_string_literal: true

require 'plumb'

module Types
  # See https://github.com/ismasan/plumb
  include Plumb::Types

  # Accepts a Money object, or an Integer amount in cents.
  Money = Any[::Money] | Lax::Integer.transform(::Money) { |v| ::Money.from_cents(v) }
end
