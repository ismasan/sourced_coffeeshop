# frozen_string_literal: true

# View helpers shared by components and pages (pages inherit from
# Sidereal::Page rather than from BaseComponent).
module ViewHelpers
  private

  def format_time(time)
    time&.strftime('%Y-%m-%d %H:%M:%S')
  end
end
