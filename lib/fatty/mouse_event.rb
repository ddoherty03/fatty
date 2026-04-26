module Fatty
  # The MouseEvent class is a simple class to store a mouse event with its
  # modifiers.
  class MouseEvent
    attr_reader :button, :x, :y, :ctrl, :meta, :shift, :raw

    def initialize(button:, x: nil, y:, raw: nil, ctrl: false, meta: false, shift: false)
      @button = button
      @x = x
      @y = y
      @raw = raw
      @ctrl = ctrl
      @meta = meta
      @shift = shift
      Fatty.debug("#{self.class}#new(#{self})", tag: :event)
    end

    def to_s
      "MouseEvent: button: `#{button}`, x: `#{x}`, y: `#{y}`, raw: `#{raw}`, ctrl: `#{ctrl}`, meta: `#{meta}`, shift: `#{shift}`"
    end

    def printable?
      false
    end

    def mouse?
      true
    end
  end
end
