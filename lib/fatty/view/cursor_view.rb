# frozen_string_literal: true

module Fatty
  class CursorView < Fatty::View
    def draw(screen:, renderer:, terminal:, session:)
      # When paging is active, the output pane owns the screen and the shell
      # input cursor should be turned off. This also prevents the underlying
      # ShellSession from overriding the cursor while a modal (e.g. SearchSession)
      # is displayed over the pager/status line.
      if session.respond_to?(:pager_active?) && session.pager_active?
        ::Curses.curs_set(0)
      else
        ::Curses.curs_set(1)
        renderer.restore_cursor(session.field)
      end
    end
  end
end
