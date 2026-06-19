# frozen_string_literal: true

module Fatty
  module OutputApi
    def append(text, follow: true)
      queue(Command.session(output_id, :append, text: text.to_s, follow: follow))
      nil
    end

    def append_now(text, follow: true, mode: nil)
      cmd = Command.session(output_id, :append, text: text.to_s, follow:, mode:)
      terminal.apply_command(cmd)
      nil
    end

    def markdown(text)
      md = Fatty::Markdown.render(
        text,
        palette: terminal.renderer.palette,
      )
      append(md)
      nil
    end
  end
end
