# frozen_string_literal: true

module FatTerm
  RSpec.describe InputField do
    def prompt(text = "> ")
      Prompt.new { text }
    end

    it "starts empty with prompt text" do
      f = InputField.new(prompt: prompt("p> "))
      expect(f.prompt_text).to eq("p> ")
      expect(f.empty?).to be(true)
      expect(f.buffer.text).to eq("")
      expect(f.buffer.cursor).to eq(0)
    end

    it "cursor_x is prompt_width + buffer cursor (exact)" do
      f = InputField.new(prompt: prompt("p> "))
      f.act_on(:insert, "abc") # via actions to prove dispatch works with args
      expect(f.cursor_x).to eq("p> ".length + 3)

      f.act_on(:move_left)
      expect(f.cursor_x).to eq("p> ".length + 2)
    end

    it "accept_line returns line, clears buffer, and adds to history" do
      h = History.new
      f = InputField.new(prompt: prompt("> "), history: h)

      f.act_on(:insert, "hello")
      line = f.act_on(:accept_line)

      expect(line).to eq("hello")
      expect(f.buffer.text).to eq("")
      expect(f.buffer.cursor).to eq(0)

      # History has no public entries reader in some versions; assert behavior:
      expect(h.previous("")).to eq("hello")
    end

    it "act_on falls back to calling buffer methods when the action isn't registered" do
      FatTerm::Actions.reset!  # simulate minimal load / no registration

      buf = FatTerm::InputBuffer.new
      field = FatTerm::InputField.new(buffer: buf, prompt: prompt('hello $ '))

      field.act_on(:insert, "xxxxx")
      expect(buf.text).to eq("xxxxx")
    end

    it "act_on raises ActionError when neither registry nor target responds" do
      FatTerm::Actions.reset!

      buf = FatTerm::InputBuffer.new
      field = FatTerm::InputField.new(buffer: buf, prompt: prompt('hello $ '))

      expect {
        field.act_on(:definitely_not_real)
      }.to raise_error(FatTerm::ActionError, /Unknown action: definitely_not_real/i)
    end

    it "history_prev replaces buffer with previous entry" do
      h = History.new
      h.add("one")
      h.add("two")

      f = InputField.new(prompt: prompt("> "), history: h)
      f.act_on(:insert, "typing")

      f.act_on(:history_prev)
      expect(f.buffer.text).to eq("two")
    end

    it "history_next returns toward scratch, then empty when done" do
      h = History.new
      h.add("one")
      h.add("two")

      f = InputField.new(prompt: prompt("> "), history: h)
      f.act_on(:insert, "typing")

      f.act_on(:history_prev) # -> "two"
      f.act_on(:history_prev) # -> "one"

      f.act_on(:history_next) # -> "two"
      expect(f.buffer.text).to eq("two")

      f.act_on(:history_next) # -> scratch ("typing")
      expect(f.buffer.text).to eq("typing")

      f.act_on(:history_next) # -> ""
      expect(f.buffer.text).to eq("")
    end

    it "history actions are no-ops when no history object is provided" do
      f = InputField.new(prompt: prompt("> "))
      f.act_on(:insert, "typing")

      expect { f.act_on(:history_prev) }.not_to raise_error
      expect { f.act_on(:history_next) }.not_to raise_error
      expect(f.buffer.text).to eq("typing")
    end

    it "dispatches buffer actions and resets history cursor for non-history actions" do
      h = History.new
      h.add("one")
      h.add("two")

      f = InputField.new(prompt: prompt("> "), history: h)
      f.act_on(:insert, "typing")

      # Enter history navigation state
      f.act_on(:history_prev)
      expect(f.buffer.text).to eq("two")

      # Non-history action => history cursor reset
      f.act_on(:move_left)

      # Now history_next behaves as if no active cursor => ""
      f.act_on(:history_next)
      expect(f.buffer.text).to eq("")
    end

    it "raises ArgumentError for unknown actions" do
      f = InputField.new(prompt: prompt("> "))
      expect { f.act_on(:no_such_action) }.to raise_error(ActionError)
    end
  end
end
