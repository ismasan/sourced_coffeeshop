module Components
  class StatusBadge < BaseComponent
    def initialize(status = 'new', label: nil)
      @status = status
      @label = label || status
    end

    def view_template
      span(class: ['status-badge', @status]) { @label }
    end
  end
end
