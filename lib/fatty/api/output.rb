# frozen_string_literal: true

module Fatty
  module OutputApi
    def append(text, follow: true)
      queue(Command.session(output_id, :append, text: text.to_s, follow: follow))
    end

    def markdown(text)
      md = Fatty::Markdown.render(
        text,
        palette: terminal.renderer.palette,
      )
      append(md)
    end
  end
end
