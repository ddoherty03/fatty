# frozen_string_literal: true

require "tmpdir"

module Fatty
  class KeyTestSession < Session
    def id = :keytest

    def initialize(owner: nil)
      super(keymap: nil, views: [])
      @owner = owner
    end

    def init(terminal:)
      super
      @suggestions = []
      @owner ||= terminal.focused_session
      show_quit_status
      force_scrolling_output!
      append <<~TEXT
        Key test mode

        Press keys to inspect Fatty's decoding and binding resolution.
        Press q, ESC, or C-g to leave key test mode.

      TEXT
      []
    end

    def update_key(ev)
      if quit_key?(ev)
        append "Leaving key test mode.\n\n"
        return [[:terminal, :pop_modal]]
      end

      append report_for(ev)
      show_quit_status
      []
    end

    def view(screen:, renderer:)
      # Intentionally blank. The underlying shell session renders the output
      # pane; this modal only captures keys and appends diagnostic text.
      nil
    end

    def close
      write_suggestions!
      restore_owner_pager!
      terminal.clear_status if terminal.respond_to?(:clear_status)
      nil
    end

    private

    def append(text)
      return unless @owner && @owner.respond_to?(:append_output)

      force_scrolling_output!

      before = @owner.output.lines.length
      @owner.append_output(text.to_s, follow: false)

      height = @owner.viewport.height.to_i
      added = @owner.output.lines.length - before

      if added >= height
        @owner.viewport.top = before
        @owner.viewport.clamp!(@owner.output.lines)
      else
        @owner.viewport.page_bottom(@owner.output.lines)
      end

      terminal.renderer.reset_frame_cache if terminal.respond_to?(:renderer)
    end

    def force_scrolling_output!
      if @owner && @owner.respond_to?(:pager)
        @owner.pager.paging_to_scrolling
      end
    end

    def quit_key?(ev)
      ev.key == :q ||
        ev.key == :escape ||
        (ev.key == :g && ev.ctrl?)
    end

    def show_quit_status
      terminal.warn("KeyTest — press q, ESC, or C-g to quit")
    end

    def report_for(ev)
      contexts = current_contexts
      binding = binding_for(ev, contexts: contexts)
      color =
        if !ev.decoded?
          :oops
        elsif binding.nil?
          :warn
        else
          :good
        end
      status =
        if !ev.decoded?
          "(UNCODED)"
        elsif binding.nil?
          "(UNBOUND)"
        else
          "(BOUND)"
        end

      rule = colored_rule(color) + "\n"

      out = +""
      out << rule
      out << colorize_report("Key report #{status}:\n", color)
      out << "  TERM:      #{terminal_name}\n"
      out << "  code:      #{code_from_event(ev).inspect}\n"
      out << "  raw:       #{ev.raw.inspect}\n"
      out << "  bytes:     #{raw_bytes(ev.raw).inspect}\n"
      out << "  key:       #{ev.key.inspect}\n"
      out << "  name:      #{key_name(ev)}\n"
      out << "  text:      #{ev.text.inspect}\n"
      out << "  modifiers: #{modifier_text(ev)}\n"
      out << "  contexts:  #{contexts.join(', ')}\n"
      out << "  binding:   #{binding_text(binding)}\n"

      unless ev.decoded?
        snippet = suggested_keydef(ev)
        @suggestions << snippet
        out << "\n"
        out << snippet
      end

      if ev.decoded? && binding.nil?
        snippet = suggested_keybinding(ev, contexts: contexts)
        @suggestions << snippet
        out << "\n"
        out << snippet
      end

      out << "\n"
      out
    end

    def terminal_name
      env =
        if terminal.respond_to?(:env)
          terminal.env
        else
          terminal.instance_variable_get(:@env)
        end

      env && env[:terminal] || ENV.fetch("TERM", "unknown")
    end

    def current_contexts
      if @owner && @owner.respond_to?(:keymap_contexts)
        @owner.keymap_contexts
      else
        [:input, :terminal]
      end
    end

    def binding_for(ev, contexts:)
      return unless @owner && @owner.respond_to?(:keymap) && @owner.keymap

      @owner.keymap.binding_for(ev, contexts: contexts)
    end

    def key_name(ev)
      ev.decoded? ? ev.to_s : "(none)"
    end

    def modifier_text(ev)
      mods = []
      mods << "ctrl" if ev.ctrl?
      mods << "meta" if ev.meta?
      mods << "shift" if ev.shift?
      mods.empty? ? "(none)" : mods.join(", ")
    end

    def binding_text(binding)
      case binding
      when nil
        "(none)"
      when Array
        action = binding[0]
        args = binding[1..] || []
        args.empty? ? action.inspect : "#{action.inspect} #{args.inspect}"
      else
        binding.inspect
      end
    end

    def raw_bytes(raw)
      case raw
      when Array
        raw.flat_map { |item| raw_bytes(item) }
      when String
        raw.bytes
      when Integer
        [raw]
      else
        []
      end
    end

    def suggested_keydef(ev)
      code = code_from_event(ev)
      return "" unless code

      <<~TEXT
        No key name is associated with this keycode.

        Suggested keydefs.yml entry:

        #{terminal_name}:
          map:
            #{code}:
              key: key_name
              ctrl: <true/false>
              meta: <true/false>
      TEXT
    end

    def code_from_event(ev)
      raw = ev.raw
      case raw
      when Integer
        raw
      when Array
        raw.reverse.find { |item| item.is_a?(Integer) }
      end
    end

    def suggested_keybinding(ev, contexts:)
      key = key_name(ev)

      lines = []
      lines << "Suggested keybindings.yml entry:"
      lines << ""
      lines << "- key: #{key}"

      if contexts.include?("paging") && !contexts.include?("input")
        lines << "  context: paging"
      end

      lines << "  ctrl: true" if ev.ctrl?
      lines << "  meta: true" if ev.meta?
      lines << "  shift: true" if ev.shift?

      lines << "  action: your_action"

      lines.join("\n")
    end

    def write_suggestions!
      suggestions = @suggestions.uniq
      return if suggestions.empty?

      path = File.join(
        Dir.tmpdir,
        "fatty-keytest-#{Time.now.strftime('%Y%m%d-%H%M%S')}.yml"
      )

      File.write(path, suggestions.join("\n\n"))

      append <<~TEXT
    =======================================================
    KeyTest suggestions written to:
      #{path}

  TEXT

      terminal.good("KeyTest suggestions written to #{path}")
    end

    def restore_owner_pager!
      if @owner && @owner.respond_to?(:pager)
        @owner.pager.quit_paging
      end
    end

    def colorize_report(text, color)
      case color
      when :good
        Rainbow(text).green
      when :warn
        Rainbow(text).yellow
      when :oops
        Rainbow(text).red
      else
        text
      end
    end

    def colored_rule(color)
      colorize_report("=" * 55, color)
    end
  end
end
