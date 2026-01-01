# frozen_string_literal: true

require_relative 'keymaps/emacs'

module FatTerm
  class  KeyMap
    def initialize
      @bindings = {}
    end

    def bind(key:, ctrl: false, meta: false, shift: false, action: nil)
      @bindings[[key, ctrl, meta, shift]] = action
    end

    def resolve(event)
      return unless event

      # Return the specific binding, or it there are none, the binding for the
      # unmodified key.  Thus C-Home will do the same thing as Home unless it
      # specifically is bound.
      @bindings[[event.key, event.ctrl?, event.meta?, event.shift?]] ||
        @bindings[[event.key, false, false, false]]
    end
  end
end
