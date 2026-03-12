# frozen_string_literal: true

# This is here to supress a particular warning that is emitted by Curses mouse
# code.
module Warning
  class << self
    alias_method :fat_term_orig_warn, :warn unless method_defined?(:fat_term_orig_warn)

    def warn(msg, category: nil, **kwargs)
      return if msg.include?("undefining the allocator of T_DATA class Curses::MouseEvent")

      fat_term_orig_warn(msg, category: category, **kwargs)
    end
  end
end
