module FatTerm
  class Terminal
    attr_reader :screen, :renderer, :output, :alert_panel, :env
    attr_accessor :prompt, :keymap, :field, :mode
    attr_reader :screen, :renderer, :output, :alert_panel, :env, :key_decoder

    def initialize(prompt: 'fat_term')
      @screen   = FatTerm::Screen.new
      @renderer = FatTerm::Renderer.new(@screen)
      @output   = FatTerm::OutputBuffer.new
      @alert_panel = AlertPanel.new
      @prompt = Prompt.ensure(prompt)
      @field  = FatTerm::InputField.new(prompt: @prompt)
      @env = Env.detect
      @key_decoder = KeyDecoder.new(env: @env, config: FatTerm::Config.keydefs)
      @mode = :insert
      @keymap = Keymaps.emacs
    end

    def go(debug: false)
      if debug
        screen.diagnostic_sink = ->(msg) {
          output.append(msg)
        }
      end

      loop do
        renderer.render(
          output: output,
          input_field: field,
          alert: alert_panel.current,
        )
        raw = screen.read_raw
        event = key_decoder.decode(raw)
        next unless event

        action = keymap.resolve(event)
        output.append("ACTION=#{action.inspect}") if debug
        handled = true
        case action
        when :resize
          screen.resize
        when :accept_line
          line = field.accept_line
          output.append(line)
        when :interrupt
          break
        when :interrupt_if_empty
          @output.append("Field empty?: #{field.empty?}: #{field.buffer.text}")
          break if field.empty?
        when NilClass
          if event.text
            field.insert(event.text)
          else
            handled = false   # ← key with no mapping and no text
          end
        else
          @output.append("Field action: #{action}")
          field.act_on(action)
        end
        if handled
          alert_panel.clear unless alert_panel.current&.sticky
        elsif event.decoded?
          alert_panel.show(
            Alert.new(
              level: :info,
              message: "Unmapped key (bind in keymap)",
              details: {
                key: event.key,
                ctrl: event.ctrl?,
                meta: event.meta?,
                shift: event.shift?}))
        else
          alert_panel.show(
            Alert.new(
              level: :warning,
              message: "Unrecognized key (add to keydefs.yaml)",
              details: {
                key: event.key,
                terminal: env[:terminal]}))
        end
      end
    ensure
      screen.close
    end
  end
end
