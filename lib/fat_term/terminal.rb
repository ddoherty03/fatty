module FatTerm
  class Terminal
    attr_reader :screen, :renderer, :output
    attr_accessor :prompt, :keymap, :field

    def initialize(prompt: 'fat_term', keymap: Keymaps.emacs)
      @screen   = FatTerm::Screen.new
      @renderer = FatTerm::Renderer.new(@screen)
      @output   = FatTerm::OutputBuffer.new
      @prompt = prompt
      @field  = FatTerm::InputField.new(prompt: @prompt)
      @keymap = keymap
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
        )
        event = screen.read_key(debug:)
        if debug
          e = event
          @output.append("Event=key:#{e.key}| text:#{e.text}| shift:#{e.shift}| ctrl:#{e.ctrl}| meta:#{e.meta}")
        end
        next unless event

        action = keymap.resolve(event)
        output.append("ACTION=#{action.inspect}") if debug
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
          field.insert(event.text) if event&.text
        else
          @output.append("Field action: #{action}")
          field.act_on(action)
        end
      end
    ensure
      screen.close
    end
  end
end
