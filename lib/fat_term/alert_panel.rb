module FatTerm
  class AlertPanel
    attr_reader :current

    def show(alert)
      @current = alert
    end

    def clear
      @current = nil
    end

    def visible?
      !@current.nil?
    end
  end
end
