# frozen_string_literal: true

module FatTerm
  class Terminal
    attr_reader :sessions, :alert_panel
    attr_accessor :running

    def initialize(renderer:, screen:, alert_panel: nil)
      @renderer = renderer
      @screen = screen
      @sessions = []
      @running = false

      @alert_panel = alert_panel || AlertPanel.new
      @alert_view = Views::AlertView.new(panel: @alert_panel, z: 1_000)
    end

    # --- Main loop (event_source is injectable) ---------------------------

    # event_source must respond to #next_event(terminal:) and return:
    # - an Event instance, or
    # - nil if no event available right now
    def go(event_source:)
      @running = true

      redraw

      while @running
        event = event_source.next_event

        if event
          dispatch_event(event)
          apply_all_commands
          redraw
        else
          # If you later add TickEvent, you can generate it here.
          # For now, no busy loop: let event_source block or sleep.
        end
      end
    ensure
      @running = false
    end

    # --- Session stack ----------------------------------------------------

    def push_session(session)
      @sessions << session
      session.focus!
      session
    end

    def pop_session
      s = @sessions.pop
      @sessions.last&.focus!
      s
    end

    def focused_session
      @sessions.last
    end

    def each_active_session
      @sessions.each { |s| yield s if s.active? }
    end

    # --- Event dispatch ---------------------------------------------------

    def dispatch_event(event)
      s = focused_session
      return unless s

      result = s.update(event, terminal: self)
      result
    end

    # --- Command handling -------------------------------------------------

    def apply_all_commands
      # Drain in stack order; top-most sessions likely emit most commands,
      # but draining all keeps behavior consistent.
      @sessions.each do |s|
        s.drain_commands.each { |cmd| apply_command(cmd) }
      end
    end

    def apply_command(cmd)
      type, *rest = cmd

      case type
      when :quit
        @running = false

      when :push_session
        session = rest.fetch(0)
        push_session(session)

      when :pop_session
        pop_session

      when :alert
        payload = rest.fetch(0)
        # payload: { level:, text:, ttl: optional }
        @alert_panel.show(**payload)

      when :alert_clear
        @alert_panel.clear

      # Nice-to-have even in early demos
      when :beep
        @renderer.beep if @renderer.respond_to?(:beep)

      else
        # Keep unknown commands visible during dev.
        @alert_panel.show(level: :warn, text: "Unknown command: #{cmd.inspect}")
      end
    end

    # --- Redraw -----------------------------------------------------------

    def redraw
      @renderer.begin_frame(screen: @screen)

      # Collect views from active sessions + global overlays
      views = []
      each_active_session { |s| views.concat(s.views) }
      views << @alert_view if @alert_panel.visible?

      views.sort_by!(&:z)
      views.each do |v|
        v.render(screen: @screen, renderer: @renderer, terminal: self, session: owning_session_for(v))
      end

      @renderer.end_frame(screen: @screen)
    end

    private

    # For now we pass the focused session as "session:" to all views,
    # but some views may want their owning session.
    # This is a seam you can refine later.
    def owning_session_for(view)
      @sessions.reverse_each do |s|
        return s if s.views.include?(view)
      end
      focused_session
    end
  end
end
