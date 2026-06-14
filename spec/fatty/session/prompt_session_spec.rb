# frozen_string_literal: true

require "tmpdir"

require "spec_helper"

module Fatty
  RSpec.describe PromptSession do
    before do
      allow(::Curses).to receive(:curs_set)
    end

    def init_prompt_session(session, rows: 24, cols: 80)
      screen = instance_double(Fatty::Screen, rows: rows, cols: cols)
      renderer = instance_double(Fatty::Renderer, screen: screen)
      terminal = instance_double(Fatty::Terminal, screen: screen, renderer: renderer)

      stub_curses_window(rows: rows, cols: cols)
      session.init(terminal: terminal)
      session
    end

    describe "#initialize" do
      it "sets id, title, message, prompt, initial text, and history" do
        session = Fatty::PromptSession.new(
          initial: "four score",
          prompt: "Memo: ",
          title: "Enter memo",
          message: "Say something",
          kind: :memo,
        )
        expect(session.id).to eq(:prompt)
        expect(session.title).to eq("Enter memo")
        expect(session.message).to eq("Say something")
        expect(session.field.prompt_text).to eq("Memo: ")
        expect(session.field.buffer.text).to eq("four score")
        expect(session.history).to be_a(Fatty::History)
      end
    end

    describe "#update" do
      it "accepts the current text and sends a prompt result to the modal owner" do
        history = Fatty::History.new(path: nil)

        session = Fatty::PromptSession.new(
          initial: "four score and seven years ago",
          kind: :memo,
          history: history,
          history_ctx: { prompt: "Memo:" },
        )
        init_prompt_session(session)

        commands = update(session, :key, event: key(:enter))
        expect(commands.map(&:action)).to eq([:send_modal_owner, :pop_modal])

        owner_command = commands.first.payload.fetch(:command)
        expect(owner_command.target).to eq(:self)
        expect(owner_command.action).to eq(:prompt_result)
        expect(owner_command.payload).to eq(kind: :memo, text: "four score and seven years ago")

        expect(history.entries.last.text).to eq("four score and seven years ago")
        expect(history.entries.last.kind).to eq(:prompt)
        expect(history.entries.last.ctx).to eq({ "prompt" => "Memo:" })
      end

      it "cancels the prompt" do
        session = Fatty::PromptSession.new(initial: "draft", kind: :name)
        init_prompt_session(session)

        commands = update(session, :key, event: key(:escape))
        expect(commands.map(&:action)).to eq([:send_modal_owner, :pop_modal])

        owner_command = commands.first.payload.fetch(:command)
        expect(owner_command.target).to eq(:self)
        expect(owner_command.action).to eq(:prompt_cancelled)
        expect(owner_command.payload).to eq(
          kind: :name,
          text: "draft",
        )
      end

      it "cancels when cancel-if-empty is invoked with an empty field" do
        session = Fatty::PromptSession.new(initial: "", kind: :name)
        init_prompt_session(session)

        commands = update(session, :key, event: key(:c, ctrl: true))
        expect(commands.map(&:action)).to eq([:send_modal_owner, :pop_modal])

        owner_command = commands.first.payload.fetch(:command)
        expect(owner_command.action).to eq(:prompt_cancelled)
      end

      it "deletes forward when cancel-if-empty is invoked with a non-empty field" do
        session = Fatty::PromptSession.new(initial: "abc")
        init_prompt_session(session)

        session.field.buffer.cursor = 1

        commands = update(session, :key, event: key(:d, ctrl: true))

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("ac")
      end

      it "handles paste" do
        session = Fatty::PromptSession.new
        init_prompt_session(session)

        commands = update(session, :paste, text: "hello\nworld\n")

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("hello world ")
      end

      it "edits the field for ordinary text keys" do
        session = Fatty::PromptSession.new
        init_prompt_session(session)

        commands = update(session, :key, event: key(:a, text: "a"))

        expect(commands).to eq([])
        expect(session.field.buffer.text).to eq("a")
      end

      it "ignores unknown commands" do
        session = Fatty::PromptSession.new
        init_prompt_session(session)

        expect(update(session, :bogus)).to eq([])
      end
    end

    describe "#view" do
      it "renders the prompt popup" do
        session = Fatty::PromptSession.new
        init_prompt_session(session)

        expect(session.renderer)
          .to receive(:render_prompt_popup)
          .with(session: session)

        session.view
      end
    end

    describe "#state" do
      it "includes prompt rendering state" do
        session = Fatty::PromptSession.new(
          initial: "draft",
          prompt: "Name: ",
          title: "Title",
          message: "Message",
        )
        init_prompt_session(session, rows: 20, cols: 70)

        expect(session.state).to eq(
          [
            "Title",
            "Message",
            "Name: ",
            "draft",
            0,
            "",
            20,
            70,
          ],
        )
      end
    end
  end
end

# # frozen_string_literal: true

# require "tmpdir"
# require "fileutils"

# module Fatty
#   RSpec.describe PromptSession do
#     it "accepts the current text and records it in prompt history" do
#       Dir.mktmpdir do |dir|
#         history_path = File.join(dir, "history.jsonl")

#         session = Fatty::PromptSession.new(
#           initial: "four score and seven years ago",
#           history_path: history_path,
#           history_ctx: { prompt: "Memo:" },
#         )

#         commands = session.send(
#           :apply_action,
#           :accept_line,
#           [],
#           terminal: instance_double(Fatty::Terminal),
#           event: nil,
#         )

#         expect(commands).to eq([
#           [:terminal, :send_modal_owner, [:cmd, :prompt_result, { kind: nil, text: "four score and seven years ago" }]],
#           [:terminal, :pop_modal],
#         ])

#         expect(session.history.entries.last.text).to eq("four score and seven years ago")
#         expect(session.history.entries.last.kind).to eq(:prompt)
#         expect(session.history.entries.last.ctx).to eq({ "prompt" => "Memo:" })
#       end
#     end

#     it "stores prompt history under the supplied history context" do
#       Dir.mktmpdir do |dir|
#         history_path = File.join(dir, "history.jsonl")

#         session = Fatty::PromptSession.new(
#           initial: "Checking",
#           history_path: history_path,
#           history_ctx: { prompt: :account_name },
#         )

#         session.send(
#           :apply_action,
#           :accept_line,
#           [],
#           terminal: instance_double(Fatty::Terminal),
#           event: nil,
#         )

#         expect(session.history.entries.last.ctx).to eq({ "prompt" => :account_name })
#       end
#     end
#   end
# end
