# frozen_string_literal: true

# App-level base for all Phlex components. Sidereal's base brings the `_d`
# Datastar attribute builder, the `command` form helper and `dom_id`.
class BaseComponent < Sidereal::Components::BaseComponent
  include ViewHelpers
end
